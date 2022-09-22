#!/bin/bash
########################################################################################################################
# - Base repo checks
# - check if files exists
# - content of static files
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
source "$SCRIPT_DIRECTORY/junit.sh"

#SAMPLE="https://github.com/Ontracon/terraform-otc-module-sample.git"
#SAMPLE_REPO=$(basename $SAMPLE)

get_opts "$@"
echo -e "- Sample Repository URL: ${INF}$SAMPLE${NC}"
case $DRY_RUN in

    true) echo -e "  * ${INF}Dry Run: Skipping tests!${NC}" ;;

    *)
        if [ "$ROOT_MODULE" == "true" ]; then
            cd $SCRIPT_DIRECTORY
            # Init Junit File
            junit_init "Base Repo"
            # check for mandatoy files in repo
            echo -e "- ${INF}Check if mandatory files exists...${NC}"
            for file in ".gitignore" "README.md" ".pre-commit-config.yaml" "MODULE.md"
            do
                if [[ -f "$ROOT_DIR/$file" ]]; then
                    echo -e "  * ${OK}OK:${NC} $file exists."
                    junit_add_ok "$file is missing."
                else
                    echo -e "  * ${ERR}NOK:${NC} $file does not exists."
                    junit_add_fail "$file is NOK." "File $file does not exist"
                fi
            done

            # Compare STATIC Files
            echo -e "- ${INF}Compare static files...${NC}"
            #git clone $SAMPLE $SAMPLE_REPO &> /dev/null
            cd $SCRIPT_DIRECTORY/SAMPLES/
            for file in ".gitignore" ".pre-commit-config.yaml"
            do
                cmp -c $file $ROOT_DIR/$file &>/dev/null
                if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                    echo -e "  * ${ERR}NOK:${NC} $file"
                    diff --brief $file $ROOT_DIR/$file | tee -i ./OUT.local &>/dev/null
                    junit_add_fail "$file differs." "Static file $file diffs from standard" "`cat ./OUT.local`"
                    rm ./OUT.local
                else
                    echo -e "  * ${OK}OK:${NC} $file"
                    junit_add_ok "$file is ok."
                fi
            done
            # # Render result file
            junit_render "$RESULTS_DIR/repo.junit.xml"
            #rm -rf $SCRIPT_DIRECTORY/$SAMPLE_REPO
        else
            echo -e "  * ${INF}No root module - skipping Repo base check!${NC}"
            exit 0
        fi
        ;;
esac
hr