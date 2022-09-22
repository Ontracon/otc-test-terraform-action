#!/bin/bash

source "$SCRIPT_DIRECTORY/help.sh"
#Color for Outputs
OK='\033[0;32m'
INF='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

function hr(){
    for i in {1..125}; do echo -n -; done
    echo ""
}

function get_opts(){
    #Input Of Optional Parameters
    while getopts d:t:r:o:m:b:a:hx flag

    do
        case "${flag}" in
            d) ROOT_DIR=${OPTARG} ;;
            t) TEST_DIR=${OPTARG} ;;
            r) CLOUD_REGION=${OPTARG} ;;
            o) OUTPUT=${OPTARG} ;;
            m) ROOT_MODULE=${OPTARG} ;;
            b) TF_BACKEND_FILE=${OPTARG} ;;
            a) AUTO_CREATE_TF_BACKEND=${OPTARG} ;;
            h) help
                exit 0 ;;
            x) set -x ;;
        esac
    done

    # Fullfill prequisites
    if [[ -z "$ROOT_DIR" ]]; then
        echo -e "\e[31mError\e[0m: No Terraform working directory. Abort"
        help
        exit 1
    fi
    # Create DIR for Test Results
    RESULTS_DIR="$ROOT_DIR/.results"
    if [[ ! -d "$RESULTS_DIR" ]]; then
        mkdir $RESULTS_DIR
    fi

    # DEFINE Variables
    TFVARS="$ROOT_DIR/$TEST_DIR/terraform.$CLOUD_REGION.tfvars"
    TFBACKEND="$ROOT_DIR/$TF_BACKEND_FILE"
    REPO=${GITHUB_REPOSITORY#*/}
    if [[ -z "$MARKDOWN_FILE" ]]; then
        MARKDOWN_FILE="$ROOT_DIR/README.md"
    fi

    hr
    echo -e "Repository: ${INF}$REPO${NC}"
    echo -e "Running script: ${INF}'`basename $0`'${NC}"
    echo -e "Terraform working directory: ${INF}$ROOT_DIR${NC}"
    hr
}

function get_provider(){
    grep "hashicorp/aws" $ROOT_DIR/*.tf &>/dev/null
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        AWS="false"
    else AWS="true"
    fi
    grep "hashicorp/azurerm" $ROOT_DIR/*.tf &>/dev/null
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        AZURE="false"
    else AZURE="true"
    fi
    if [[ "$AZURE" == "true" ]]; then
        PROVIDER="azure" #
    fi
    if [[ "$AWS" == "true" ]]; then
        PROVIDER="aws" #
    fi
    if [[ "$AWS" == "true" ]] && [[ "$AZURE" == "true" ]]; then
        PROVIDER="awsandazure"
    fi
    if [[ "$AWS" == "false" ]] && [[ "$AZURE" == "false" ]]; then
        PROVIDER="none" #
    fi
}

function create_backend(){
    dir=$(basename $ROOT_DIR)


    if [[ -f "$SCRIPT_DIRECTORY/$TEST_DIR/$CLOUD_REGION.tfbackend" ]]; then
        eval $(sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g' "$SCRIPT_DIRECTORY/$TEST_DIR/$CLOUD_REGION.tfbackend")
        echo -e "  * ${OK}Auto Backend:${NC} using $SCRIPT_DIRECTORY/$TEST_DIR/$CLOUD_REGION.tfbackend for backend creation."
    else
        echo -e "  * ${ERR}Error:${NC} Automatic Backend creation failed file $SCRIPT_DIRECTORY/$TEST_DIR/$CLOUD_REGION.tfbackend not found."
        exit 1
    fi

    case $PROVIDER in
        aws)
            echo -e "  * ${OK}AWS Backend${NC}: $region,  $bucket, $dynamodb_table"
            cat <<EOF > $ROOT_DIR/auto.tfbackend.local
    region         = "$region"
    bucket         = "$bucket"
    dynamodb_table = "$dynamodb_table"
    key            = "$REPO/$dir.tfstate"
    encrypt        = true
EOF
            ;;
        azure)
            echo -e "  * ${OK}Azure Backend${NC}: $resource_group_name,  $storage_account_name, $container_name"
            cat <<EOF > $ROOT_DIR/auto.tfbackend.local
    resource_group_name  = "$resource_group_name"
    storage_account_name = "$storage_account_name"
    container_name       = "$container_name"
    key                  = "$REPO/$dir.tfstate"
EOF
            ;;
        *)
            echo -e "  * ${ERR}Error:${NC} Automatic Backend creation failed: ${INF}Cloud Provider could not determinated!${NC}"
            exit 1
            ;;
    esac
}

function check_aws_credentials() {
    if [[ ! -z "$AWS_ACCESS_KEY_ID" ]] && [[ ! -z "$AWS_SECRET_ACCESS_KEY" ]]; then AWSCRED_VALID="true"; else AWSCRED_VALID="false"; fi
}

function check_azure_credentials() {
    if [[ ! -z "$ARM_SUBSCRIPTION_ID" ]] && [[ ! -z "$ARM_CLIENT_ID" ]] &&  [[ ! -z "$ARM_CLIENT_SECRET" ]] && [[ ! -z "$ARM_TENANT_ID" ]]; then
        AZURECRED_VALID="true"; else AZURECRED_VALID="false";
    fi
}

function gha_notice(){
    text=$2
    text="${text//'%'/'%25'}"
    text="${text//$'\n'/'%0A'}"
    text="${text//$'\r'/'%0D'}"
    if [[ ! -z "$GITHUB_EVENT_NAME" ]]; then echo "::notice file=`basename $0`,title=$1::$text"; fi
}