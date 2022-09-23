#!/bin/bash
########################################################################################################################
# - Base Terraform checks:
# - terraform apply
# - chef inspec tests
# - terraform destroy
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
source "$SCRIPT_DIRECTORY/junit.sh"
########################################################################################################################
# Terraform functions
configure_backend(){
    case $PROVIDER in
        aws)
            rpl 'backend "local" {}' 'backend "s3" {}' $ROOT_DIR/*.tf &> /dev/null
            echo -e "  * ${OK}Auto Backend Config${NC}: AWS Backend configured."
            ;;
        azure)


            rpl 'backend "local" {}' 'backend "azurerm" {}' $ROOT_DIR/*.tf &> /dev/null
            echo -e "  * ${OK}Auto Backend Config${NC}: AzureRM Backend configured."
            ;;
        *)
            echo -e "  * ${ERR}Auto Backend Config${NC}: Could not configure Backend automatically,please provide Backend file."
            exit 1
            ;;
    esac

}

undo_configure_backend(){
    case $PROVIDER in
        aws)
            rpl 'backend "s3" {}' 'backend "local" {}' $ROOT_DIR/*.tf &> /dev/null
            ;;
        azure)
            rpl 'backend "azurerm" {}' 'backend "local" {}' $ROOT_DIR/*.tf &> /dev/null
            ;;
        *)
            echo -e "  * ${ERR}Auto Backend Config${NC}: Could not configure Backend automatically,please provide Backend file."
            exit 1
            ;;
    esac
}

terraform_init(){
    if [[ ! -f "$TFBACKEND" ]]; then
        terraform -chdir=$ROOT_DIR init -reconfigure -no-color &> OUT.local
    else
        terraform -chdir=$ROOT_DIR init -reconfigure -backend-config=$TFBACKEND -no-color &> OUT.local
    fi
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo -e "  * ${ERR}Error: terraform init failed!${NC}"
        junit_add_error "terraform init" "Terraform code not valid or backend config wrong" "`cat ./OUT.local`"

    else
        echo -e "  * ${OK}Terraform init:${NC} successful!"
        junit_add_ok "Terraform"
    fi
    if [ "$OUTPUT" == "true" ]; then echo "`cat ./OUT.local`"; fi
}

terraform_plan(){

    terraform -chdir=$ROOT_DIR plan -var-file=$TFVARS -input=false -no-color -out $ROOT_DIR/deploy.plan.local &> OUT.local
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo -e "  * ${ERR}Error: terraform plan failed!${NC}"
        junit_add_error "terraform" "Terraform plan failed. Please check output."

    else
        echo -e "  * ${OK}Terraform plan:${NC} successful!"
        grep "Warning:" OUT.local &> /dev/null
        if [[ ! ${PIPESTATUS[0]} -ne 0 ]]; then
            junit_add_fail "Terraform plan warnings" "Warning, please check for warnings in output of terraform plan."
        else
            grep "Error:" OUT.local
            if [[ ! ${PIPESTATUS[0]} -ne 0 ]]; then
                junit_add_error "Terraform plan" "Error, please check for errors in output of terraform plan."
            else
                junit_add_ok "Terraform plan"
            fi
        fi
    fi
    if [ "$OUTPUT" == "true" ]; then echo "`cat ./OUT.local`"; fi
    terraform -chdir=$ROOT_DIR show -json $ROOT_DIR/deploy.plan.local > $ROOT_DIR/deploy.plan.json.local
    # We need to strip the single quotes that are wrapping it so we can parse it with JQ
    plan=$(cat $ROOT_DIR/deploy.plan.json.local | sed "s/^'//g" | sed "s/'$//g")
    # Get the count of the number of resources being created
    create=$(echo "$plan" | jq -r ".resource_changes[].change.actions[]" | grep "create" | wc -l | sed 's/^[[:space:]]*//g')
    # Get the count of the number of resources being updated
    update=$(echo "$plan" | jq -r ".resource_changes[].change.actions[]" | grep "update" | wc -l | sed 's/^[[:space:]]*//g')
    # Get the count of the number of resources being deleted
    delete=$(echo "$plan" | jq -r ".resource_changes[].change.actions[]" | grep "delete" | wc -l | sed 's/^[[:space:]]*//g')
    echo -e "  * ${OK}Terraform plan:${NC} ${OK}$create to add${NC}, ${INF}$update to change${NC} and ${ERR}$delete to delete${NC}!"
    gha_notice "Terraform plan - `basename $ROOT_DIR` - $CLOUD_REGION" "Terraform plan `basename $ROOT_DIR`: $create to add, $update to change, $delete to destroy."
}
terraform_apply(){
    terraform -chdir=$ROOT_DIR apply $ROOT_DIR/deploy.plan.local |tee OUT.local
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo -e "  * ${ERR}Error: terraform apply failed!${NC}"
        junit_add_error "terraform" "Terraform apply failed."

    else
        echo -e "  * ${OK}Terraform apply:${NC} successful!"
        junit_add_ok "Terraform apply"
    fi
    gha_notice "terraform output `basename $ROOT_DIR` - $CLOUD_REGION" "`terraform -chdir=$ROOT_DIR output -no-color`"
    TFAPPLY="true"
}

run_inspec(){
    if [[ -d "$ROOT_DIR/$TEST_DIR/inspec-tests" ]] && [[ "$TFAPPLY" == "true" ]] ; then
        echo -e "  * ${OK}INSPEC_WAIT_TIME${NC}: Waiting for $INSPEC_WAIT_TIME seconds."
        sleep $INSPEC_WAIT_TIME
        export AZURE_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID
        export AZURE_CLIENT_ID=$ARM_CLIENT_ID
        export AZURE_CLIENT_SECRET=$ARM_CLIENT_SECRET
        export AZURE_TENANT_ID=$ARM_TENANT_ID
        export AWS_REGION=$CLOUD_REGION
        mkdir $ROOT_DIR/$TEST_DIR/inspec-tests/files &> /dev/null
        terraform -chdir=$ROOT_DIR output -json > $ROOT_DIR/$TEST_DIR/inspec-tests/files/outputs.json.local
        INSPECARGS=""
        if [[ "$AWS" == "true" ]]; then INSPECARGS="$INSPECARGS-t aws:// "; fi
        if [[ "$AZURE" == "true" ]]; then INSPECARGS="$INSPECARGS-t azure:// "; fi

        echo -e "  * ${INF}Inspec args${NC}: $INSPECARGS"
        inspec exec $ROOT_DIR/$TEST_DIR/inspec-tests --chef-license=accept-silent --input CLOUD_REGION=$CLOUD_REGION $INSPECARGS --reporter junit2:$ROOT_DIR/.results/inspec.junit.xml cli
        if [[ -d "$ROOT_DIR/$TEST_DIR/$CUSTOM_INSPEC_DIR" ]] && [[ "$TFAPPLY" == "true" ]] ; then
            echo -e "  * ${OK}CUSTOM_INSPEC_DIR${NC}: Running profile in $CUSTOM_INSPEC_DIR with $CUSTOM_INSPEC_ARG arguments."
            INSPECARGS=$CUSTOM_INSPEC_ARG
            mkdir $ROOT_DIR/$TEST_DIR/$CUSTOM_INSPEC_DIR/files &> /dev/null
            terraform -chdir=$ROOT_DIR output -json > $ROOT_DIR/$TEST_DIR/$CUSTOM_INSPEC_DIR/files/outputs.json.local
            inspec exec $ROOT_DIR/$TEST_DIR/$CUSTOM_INSPEC_DIR/ --chef-license=accept-silent --input CLOUD_REGION=$CLOUD_REGION $INSPECARGS --reporter junit2:$ROOT_DIR/.results/inspec-custom.junit.xml cli
        fi

    fi
}
terraform_destroy(){
    if [[ "$AUTO_DESTROY_AFTER_TESTS" == "true" ]]; then
        terraform -chdir=$ROOT_DIR destroy -var-file=$TFVARS -input=false --auto-approve

        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo -e "  * ${INF}Terraform destroy:${NC} First destroy not successful, will try again after $AUTO_DESTROY_WAIT_TIME Seconds!"
            sleep $AUTO_DESTROY_WAIT_TIME
            terraform -chdir=$ROOT_DIR destroy -var-file=$TFVARS -input=false --auto-approve
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                echo -e "  * ${ERR}Terraform destroy:${NC} Second destroy not successful, could not destroy resources!"
                junit_add_error "terraform" "Terraform destroy failed."
            else
                echo -e "  * ${OK}Terraform destroy:${NC} Second destroy successful."
            fi
        else
            echo -e "  * ${OK}Terraform destroy:${NC} destroy successful."
        fi
    else echo -e "  * ${INF}Terraform destroy:${NC} skipped as AUTO_DESTROY_AFTER_TESTS is $AUTO_DESTROY_AFTER_TESTS !"
    fi
}
# end functions
######################################################################################################################

get_opts "$@"

get_provider
check_aws_credentials
check_azure_credentials

if [[ "$DRY_RUN" == "true" ]]; then MESSAGE="  * ${INF}Dry Run: Skipping deployment!${NC}"; fi
if [[ "$ROOT_MODULE" == "true" ]]; then MESSAGE="  * ${INF}Root Module: Skipping deployment!${NC}"; DRY_RUN="true";
else
    junit_init "TF Deploy"
    if [[ "$AWSCRED_VALID" == "true" ]] || [[ "$AZURECRED_VALID" == "true" ]]; then
        echo -e "  * ${OK}Cloud Credentials${NC}: Cloud Credentials ok."
        junit_add_ok "Cloud credentials ok."
    else
        echo -e "  * ${ERR}Cloud Credentials${NC}: Cloud Credentials missing."
        junit_add_error "terraform" "Missing Cloud credentials." "Found $PROVIDER, Provided Credentials AWS: $AWSCRED_VALID, Azure: $AZURECRED_VALID"
    fi
    if [[ "$AUTO_CREATE_TF_BACKEND" == "true" ]]; then
        TFBACKEND="$ROOT_DIR/auto.tfbackend.local"
        echo -e "  * ${OK}Auto Backend${NC}: $AUTO_CREATE_TF_BACKEND"
    fi
    if [[ ! -f "$TFBACKEND" ]]; then
        echo -e "  * ${INF}TFBACKEND${NC}: No $TFBACKEND file found. Deployment Test will run with local backend file."
    else echo -e "  * ${OK}Backend${NC}: Using $TFBACKEND file."
    fi
fi

case $DRY_RUN in

    true) echo -e "$MESSAGE" ;;
    *)
        if [[ "$AUTO_CREATE_TF_BACKEND" == "true" ]]; then
            configure_backend
        fi
        if [[ ! -f "$TFVARS" ]]; then
            echo -e "  * ${ERR}TFVARS${NC}: No $TFVARS file found. No Deployment Test will run."
            junit_add_error "terraform" "Missing tfvars, file $TFVARS not found"
        else
            echo -e "  * ${OK}TFVARS${NC}: $TFVARS"
            junit_add_ok "$TFVARS ok."
        fi
        if [[ $err == 0 ]]; then
            terraform_init
            terraform_plan
            if [[ "$DEPLOYMENT_TEST" == "true" ]]; then
                echo -e "  * ${OK}DEPLOYMENT_TEST${NC}: $DEPLOYMENT_TEST, run deployment test on $GITHUB_REF_NAME"
                terraform_apply
                run_inspec
            else
                if [[ "$DEPLOYMENT_TEST_ON_MAIN" == "true" ]] && [[ "$GITHUB_REF_NAME" == "main" ]] ; then
                    echo -e "  * ${OK}DEPLOYMENT_TEST_ON_MAIN${NC}: $DEPLOYMENT_TEST_ON_MAIN, run deployment test on $GITHUB_REF_NAME"
                    terraform_apply
                    run_inspec
                else
                    if [[ "$DEPLOYMENT_TEST_ON_PR" == "true" ]] && [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
                        echo -e "  * ${OK}DEPLOYMENT_TEST_ON_PR${NC}: $DEPLOYMENT_TEST_ON_PR, run deployment test on $GITHUB_REF"
                        terraform_apply
                        run_inspec
                    else
                        echo -e "  * ${INF}Skipping Deployment${NC}: None of DEPLOYMENT_TEST_ON_PR, DEPLOYMENT_TEST_ON_MAIN or DEPLOYMENT_TEST set"
                        gha_notice "terraform apply  - `basename $ROOT_DIR` - $CLOUD_REGION" "Deployment was skipped. None of DEPLOYMENT_TEST_ON_PR, DEPLOYMENT_TEST_ON_MAIN or DEPLOYMENT_TEST was fullfilled."
                    fi
                fi
            fi
        fi
        terraform_destroy
        # Undo changes
        if [[ "$AUTO_CREATE_TF_BACKEND" == "true" ]]; then
            undo_configure_backend
        fi
        junit_render "$RESULTS_DIR/terraform.junit.xml"
        ;;
esac
