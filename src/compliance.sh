#!/bin/bash
########################################################################################################################
# - Base Terraform checks:
# - terraform fmt --check
# - terraform init & terraform validate
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
get_opts "$@"

########################################################################################################################
# compliance functions
function terraform_compliance()
{
    mkdir -p ~/.tflint.d
    unzip $SCRIPT_DIRECTORY/install/tflint-ruleset-aws_linux_amd64.zip -d ~/.tflint.d/plugins
    unzip $SCRIPT_DIRECTORY/install/tflint-ruleset-azurerm_linux_amd64.zip -d ~/.tflint.d/plugins
    dir=$(basename $ROOT_DIR)
    echo -e "  * ${OK}Tflint Version:${NC} "
    tflint --version
    if [[ -f "$ROOT_DIR/.tflint.hcl" ]]; then
        TFLINT_CONFIG="$ROOT_DIR/.tflint.hcl"
    else
        TFLINT_CONFIG="$SCRIPT_DIRECTORY/tflint.hcl"
    fi
    export GITHUB_TOKEN=$ATC
    cd $ROOT_DIR
    if [[ ! -f "$TFVARS" ]]; then
        tflint --force -c $TFLINT_CONFIG $TFLINTARGS -f junit > "$RESULTS_DIR/tflint.junit.xml"
        if [ "$OUTPUT" == "true" ]; then
            tflint --force -c $TFLINT_CONFIG $TFLINTARGS
        fi
    else
        tflint --force -c $TFLINT_CONFIG --var-file=$TFVARS -f junit > "$RESULTS_DIR/tflint.junit.xml"
        if [ "$OUTPUT" == "true" ]; then
            tflint --force -c $TFLINT_CONFIG --var-file=$TFVARS $TFLINTARGS
        fi
    fi

    rpl -e 'name="">' 'name="TF linter">' $RESULTS_DIR/tflint.junit.xml &> /dev/null
    rpl -e 'classname="' 'classname="'$dir' - ' $RESULTS_DIR/tflint.junit.xml &> /dev/null
    cd $SCRIPT_DIRECTORY
}
# end functions
######################################################################################################################
get_provider
if [[ -f "$ROOT_DIR/.tflint.hcl" ]]; then echo -e "  * ${INF}Custom tflint config:${NC} Using $ROOT_DIR/.tflint.hcl";
else echo -e "  * ${OK}CNA tflint config${NC}: Using $SCRIPT_DIRECTORY/tflint.hcl"; fi
TFLINTARGS=""
if [[ "$AZURE" == "true" ]]; then TFLINTARGS="$TFLINTARGS--enable-plugin=azurerm "; fi
if [[ "$AWS" == "true" ]]; then TFLINTARGS="$TFLINTARGS--enable-plugin=aws "; fi
if [[ "$ROOT_MODULE" == "true" ]]; then TFLINTARGS="$TFLINTARGS--enable-plugin=cna "; fi
echo -e "  * ${INF}tflint args${NC}: $TFLINTARGS"
terraform_compliance