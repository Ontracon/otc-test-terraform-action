#!/bin/bash
########################################################################################################################
# - Base Terraform checks:
# - terraform fmt --check
# - terraform init & terraform validate
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
source "$SCRIPT_DIRECTORY/junit.sh"
########################################################################################################################
# Terraform functions
function terraform_fmt_check(){
    terraform -chdir=$ROOT_DIR fmt -check -no-color &> OUT.local
}

function terraform_init(){
    if [[ ! -f "$TFBACKEND" ]]; then
        terraform -chdir=$ROOT_DIR init -reconfigure -no-color &> OUT.local
    else
        get_provider
        check_aws_credentials
        check_azure_credentials
        terraform -chdir=$ROOT_DIR init -reconfigure -backend-config=$TFBACKEND -no-color &> OUT.local
    fi
    if [ "$OUTPUT" == "true" ]; then cat OUT.local; fi
}

function terraform_validate(){
    terraform -chdir=$ROOT_DIR validate -json > tf_validate_result.json
    terraform -chdir=$ROOT_DIR validate -no-color &> OUT.local
    if [ "$OUTPUT" == "true" ]; then
        terraform -chdir=$ROOT_DIR validate
    fi
    result=`jq '.valid' tf_validate_result.json`
    errors=`jq '.error_count' tf_validate_result.json`
    warnings=`jq '.warning_count' tf_validate_result.json`
    rm tf_validate_result.json
    if [ ! "$errors" == 0 ]; then
        junit_add_error "terraform validate" "Terraform code not valid" "`cat ./OUT.local`"
    else junit_add_ok "validate - errors success."
    fi
    if [ ! "$warnings" == 0 ]; then
        junit_add_fail "terraform validate" "Terraform valid, but has $warn Warnings" "`cat ./OUT.local`"
    else junit_add_ok "validate - warnings success."
    fi
    if [[ "$result" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# end functions
######################################################################################################################

get_opts "$@"
junit_init "TF Base"

if [[ -z "$TF_BACKEND_FILE" ]]; then
    echo -e "  * ${INF}TF_BACKEND_FILE${NC}: No TF_BACKEND_FILE set."
else echo -e "  * ${OK}TF_BACKEND_FILE${NC}: $TF_BACKEND_FILE"
fi

case $DRY_RUN in

    true) echo -e "  * ${INF}Dry Run: Skipping tests!${NC}" ;;

    *)
        # Terraform Init
        TFBACKEND="$ROOT_DIR/$TF_BACKEND_FILE"
        if [[ ! -f "$TFBACKEND" ]]; then
            echo -e "  * ${INF}TFBACKEND${NC}: No $TFBACKEND file found. Init will run with local backend file."
        else echo -e "  * ${OK}Backend${NC}: Using $TFBACKEND file."
        fi
        terraform_init
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo -e "  * ${ERR}Error: terraform init failed!${NC}"
            junit_add_error "terraform init" "Terraform code not valid" "`cat ./OUT.local`"
        else
            echo -e "  * ${OK}Terraform init:${NC} successful!"
        fi
        # Terraform format
        terraform_fmt_check
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo -e "  * ${ERR}Error: terraform format check failed!${NC}"
            junit_add_fail "terraform fmt" "Terraform format not valid" "`cat ./OUT.local`"
        else
            echo -e "  * ${OK}Terraform fmt check:${NC} successful!"
            junit_add_ok "format is ok."
        fi

        terraform_validate
        if [[ $? -ne 0 ]]; then
            echo -e "  * ${ERR}Error:${NC} terraform validate failed with ${ERR} $err errors, ${INF}$warn warnings${NC}!"
        else
            echo -e "  * ${OK}Terraform validate:${NC} successful with ${INF}$warn warnings${NC}!"
        fi
        # Render result file
        ERRORS=$err
        junit_render "$RESULTS_DIR/base.junit.xml"
        if [[ $ERRORS -ne 0 ]]; then
            echo -e "  * ${ERR}Terraform Error:${NC} Terraform code not valid!"
            exit 1
        else
            echo -e "  * ${OK}Terraform:${NC} Terraform code valid!"
            exit 0
        fi
        ;;
esac
hr