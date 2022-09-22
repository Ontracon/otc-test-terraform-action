#!/bin/bash
########################################################################################################################
# Pre-Flight checks:
# - Check if all necessary paramater are given
#
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
get_opts "$@"

########################################################################################################################
# pre-filght check functions
function check_variables(){
    echo -e "- Mandatory Variables:"
    echo -e "  * ${OK}ROOT_DIR${NC}: $ROOT_DIR"

    # Check for Github Token
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo -e "  * ${ERR}GITHUB_TOKEN${NC}: No GITHUB_TOKEN set. Abort"
        exit 1
    else echo -e "  * ${OK}GITHUB_TOKEN${NC}: $GITHUB_TOKEN"
    fi

    echo -e "- Optional Variables:"
    if [[ -z "$TEST_DIR" ]]; then
        echo -e "  * ${INF}TEST_DIR${NC}: No TEST_DIR set."
    else echo -e "  * ${OK}TEST_DIR${NC}: $TEST_DIR"
    fi

    if [[ -z "$CLOUD_REGION" ]]; then
        echo -e "  * ${INF}CLOUD_REGION${NC}: No CLOUD_REGION set."
    else echo -e "  * ${OK}CLOUD_REGION${NC}: $CLOUD_REGION"
    fi

    if [[ -z "$OUTPUT" ]]; then
        echo -e "  * ${INF}OUTPUT${NC}: No OUTPUT set."
    else echo -e "  * ${OK}OUTPUT${NC}: $OUTPUT"
    fi

    if [[ -z "$ROOT_MODULE" ]]; then
        echo -e "  * ${INF}ROOT_MODULE${NC}: No ROOT_MODULE set."
    else echo -e "  * ${OK}ROOT_MODULE${NC}: $ROOT_MODULE"
    fi
    if [[ -z "$PUBLIC_GITHUB_TOKEN" ]]; then
        echo -e "  * ${INF}PUBLIC_GITHUB_TOKEN${NC}: No PUBLIC_GITHUB_TOKEN set."
    else echo -e "  * ${OK}PUBLIC_GITHUB_TOKEN${NC}: $ROOT_MODULE"
    fi
    if [[ -z "$FAIL_ON" ]]; then
        echo -e "  * ${INF}FAIL_ON${NC}: No FAIL_ON set."
    else echo -e "  * ${OK}FAIL_ON${NC}: $FAIL_ON"
    fi
    if [[ -z "$DEPLOYMENT_TEST" ]]; then
        echo -e "  * ${INF}DEPLOYMENT_TEST${NC}: No DEPLOYMENT_TEST set."
    else echo -e "  * ${OK}DEPLOYMENT_TEST${NC}: $DEPLOYMENT_TEST"
    fi
    if [[ -z "$DEPLOYMENT_TEST_ON_PR" ]]; then
        echo -e "  * ${INF}DEPLOYMENT_TEST_ON_PR${NC}: No DEPLOYMENT_TEST_ON_PR set."
    else echo -e "  * ${OK}DEPLOYMENT_TEST_ON_PR${NC}: $DEPLOYMENT_TEST_ON_PR"
    fi
    if [[ -z "$DEPLOYMENT_TEST_ON_MAIN" ]]; then
        echo -e "  * ${INF}DEPLOYMENT_TEST_ON_MAIN${NC}: No DEPLOYMENT_TEST_ON_MAIN set."
    else echo -e "  * ${OK}DEPLOYMENT_TEST_ON_MAIN${NC}: $DEPLOYMENT_TEST_ON_MAIN"
    fi
    if [[ -z "$CUSTOM_INSPEC_DIR" ]]; then
        echo -e "  * ${INF}CUSTOM_INSPEC_DIR${NC}: No CUSTOM_INSPEC_DIR set."
    else echo -e "  * ${OK}CUSTOM_INSPEC_DIR${NC}: $CUSTOM_INSPEC_DIR"
    fi
    if [[ -z "$CUSTOM_INSPEC_ARG" ]]; then
        echo -e "  * ${INF}CUSTOM_INSPEC_ARG${NC}: No CUSTOM_INSPEC_ARG set."
    else echo -e "  * ${OK}CUSTOM_INSPEC_ARG${NC}: $CUSTOM_INSPEC_ARG"
    fi
    if [[ -z "$INSPEC_WAIT_TIME" ]]; then
        echo -e "  * ${INF}INSPEC_WAIT_TIME${NC}: No INSPEC_WAIT_TIME set."
    else echo -e "  * ${OK}INSPEC_WAIT_TIME${NC}: $INSPEC_WAIT_TIME"
    fi
    if [[ -z "$GITHUB_EVENT_NAME" ]]; then
        echo -e "  * ${INF}GITHUB_EVENT_NAME${NC}: No GITHUB_EVENT_NAME set."
    else
        if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
            echo -e "  * ${OK}GITHUB_EVENT_NAME${NC}: Current event is Pull Request."
        else echo -e "  * ${OK}GITHUB_EVENT_NAME${NC}: Current event is '$GITHUB_EVENT_NAME'."
        fi
    fi
    echo -e "  * ${OK}GITHUB Workflow run${NC}: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
    if [[ -z "$AUTO_CREATE_TF_BACKEND" ]]; then
        echo -e "  * ${INF}AUTO_CREATE_TF_BACKEND${NC}: No AUTO_CREATE_TF_BACKEND set."
    else echo -e "  * ${OK}AUTO_CREATE_TF_BACKEND${NC}: $AUTO_CREATE_TF_BACKEND"
    fi

    if [[ -z "$TF_BACKEND_FILE" ]]; then
        echo -e "  * ${INF}TF_BACKEND_FILE${NC}: No TF_BACKEND_FILE set."
    else echo -e "  * ${OK}TF_BACKEND_FILE${NC}: $TF_BACKEND_FILE"
    fi
    if [[ -z "$AUTO_DESTROY_AFTER_TESTS" ]]; then
        echo -e "  * ${INF}AUTO_DESTROY_AFTER_TESTS${NC}: No AUTO_DESTROY_AFTER_TESTS set."
    else echo -e "  * ${OK}AUTO_DESTROY_AFTER_TESTS${NC}: $AUTO_DESTROY_AFTER_TESTS"
    fi
    if [[ -z "$AUTO_DESTROY_WAIT_TIME" ]]; then
        echo -e "  * ${INF}AUTO_DESTROY_WAIT_TIME${NC}: No AUTO_DESTROY_WAIT_TIME set."
    else echo -e "  * ${OK}AUTO_DESTROY_WAIT_TIME${NC}: $AUTO_DESTROY_WAIT_TIME"
    fi
    if [[ -z "$DRY_RUN" ]]; then
        echo -e "  * ${INF}DRY_RUN${NC}: No DRY_RUN set."
    else echo -e "  * ${OK}DRY_RUN${NC}: $DRY_RUN ${ERR}NO TEST WILL BE EXECUTED!{$NC}"
    fi
    echo -e "  * ${OK}Badges${NC}: File for badges $MARKDOWN_FILE"
}

function check_files(){
    echo "- Files"
    if [[ ! -f "$TFVARS" ]]; then
        echo -e "  * ${INF}TFVARS${NC}: No $TFVARS file found. No Deployment Test will run."
    else echo -e "  * ${OK}TFVARS${NC}: $TFVARS"
    fi

    if [[ ! -f "$TFBACKEND" ]]; then
        if [[ ! "$AUTO_CREATE_TF_BACKEND" == "true" ]]; then
            echo -e "  * ${INF}TFBACKEND${NC}: No $TFBACKEND file found. Deployment Test will run with local backend file."
        else echo -e "  * ${OK}TFBACKEND${NC}: Auto create is $AUTO_CREATE_TF_BACKEND, Backend config will be created."
        fi
    else echo -e "${OK}TFBACKEND${NC}: $TFBACKEND"
    fi
}

function check_cloud_provider(){
    echo "- Cloud Provider"
    case $PROVIDER in
        aws)
            echo -e "  * ${OK}Provider${NC}: $PROVIDER (AWS:$AWS , AZURE:$AZURE)"
            if [[ "$AWSCRED_VALID" == "true" ]]; then echo -e "  * ${OK}AWS Credentials${NC}: valid - $AWSCRED_VALID (AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID)";  else echo -e "  * ${ERR}AWS Credentials${NC}: valid - $AWSCRED_VALID"; fi
            ;;
        azure)
            echo -e "  * ${OK}Provider${NC}: $PROVIDER (AWS:$AWS , AZURE:$AZURE)"
            if [[ "$AZURECRED_VALID" == "true" ]]; then echo -e "  * ${OK}Azure Credentials${NC}: valid - $AZURECRED_VALID (ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID: $ARM_CLIENT_ID, ARM_TENANT_ID: $ARM_TENANT_ID)";  else echo -e "  * ${ERR}Azure Credentials${NC}: valid - $AZURECRED_VALID"; fi
            ;;
        awsandazure)
            echo -e "  * ${INF}Provider${NC}: AWS & AZURE (AWS:$AWS , AZURE:$AZURE)"
            if [[ "$AWSCRED_VALID" == "true" ]]; then echo -e "  * ${OK}AWS Credentials${NC}: valid - $AWSCRED_VALID (AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID)";  else echo -e "  * ${ERR}AWS Credentials${NC}: valid - $AWSCRED_VALID"; fi
            if [[ "$AZURECRED_VALID" == "true" ]]; then echo -e "  * ${OK}Azure Credentials${NC}: valid - $AZURECRED_VALID (ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID: $ARM_CLIENT_ID, ARM_TENANT_ID: $ARM_TENANT_ID)";  else echo -e "  * ${ERR}Azure Credentials${NC}: valid - $AZURECRED_VALID"; fi
            ;;
        *)
            echo -e "  * ${ERR}Provider${NC}: $PROVIDER (AWS:$AWS , AZURE:$AZURE)"
            ;;
    esac

}
# Start checks
get_provider
check_aws_credentials
check_azure_credentials
check_variables
check_files
check_cloud_provider
echo "- Auto Backend"
if [[ "$AUTO_CREATE_TF_BACKEND" == "true" ]] && [[ ! "$ROOT_MODULE" == "true" ]]; then
    create_backend
    echo "--- Created: $ROOT_DIR/auto.tfbackend.local"
    cat $ROOT_DIR/auto.tfbackend.local
    echo "---"
fi
hr
# End checks