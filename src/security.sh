#!/bin/bash
########################################################################################################################
# Security checks:
# - checkov
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
get_opts "$@"
########################################################################################################################
# seurity functions
function terraform_checkov()
{
    UNIT_RESULTS="$RESULTS_DIR/checkov.junit.xml"
    cd $ROOT_DIR
    if [[ ! -f "$TFVARS" ]]; then
        checkov -d . --download-external-modules false -o junitxml > $UNIT_RESULTS
    else
        checkov -d . --download-external-modules false -o junitxml --var-file $TFVARS > $UNIT_RESULTS
    fi
    rpl -e 'classname="/' 'classname="'$dir' - ' $UNIT_RESULTS &> /dev/null
    if [ "$OUTPUT" == "true" ]; then
        checkov -d .
    fi
    cd $SCRIPT_DIRECTORY
}
case $DRY_RUN in

    true) echo -e "  * ${INF}Dry Run: Skipping tests!${NC}" ;;
    *)
        terraform_checkov
        hr
        ;;
esac