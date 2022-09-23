#!/bin/bash
########################################################################################################################
# Pre-Flight checks:
# - Check if all necessary paramater are given
#
#
######################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
RESULTS_DIR="$ROOT_DIR/.results"

get_test_results(){
    JUNIT=$1
    COUNT=0; ERRORS=0; FAIL=0; SKIPPED=0
    JNAME=`xmllint --xpath 'string(//testsuites/testsuite/@name)' $JUNIT`
    COUNT=`xmllint --xpath 'string(//testsuites/testsuite/@tests)' $JUNIT`
    ERRORS=`xmllint --xpath 'string(//testsuites/testsuite/@errors)' $JUNIT`
    FAIL=`xmllint --xpath 'string(//testsuites/testsuite/@failures)' $JUNIT`
    SKIPPED=`xmllint --xpath 'string(//testsuites/testsuite/@skipped)' $JUNIT`
    if [[ -z $SKIPPED ]]; then SKIPPED=0; fi
}
get_badge_url(){
    JUNIT_FILE=$1 LABEL=$2 LOGO=$3
    COLOR="inactive"
    COUNT=0; ERRORS=0; FAIL=0; SKIPPED=0
    if [[ -f "$1" ]]; then
        get_test_results $1
        if [[ "$SKIPPED" -ne "0" ]]; then COLOR="green"; fi
        if [[ "$FAIL" -ne "0" ]]; then COLOR="yellow"; fi
        if [[ "$ERRORS" -ne "0" ]]; then COLOR="critical"; fi
        if [[ "$SKIPPED" -eq "0" ]] && [[ "$FAIL" -eq "0" ]] && [[ "$ERRORS" -eq "0" ]]; then COLOR="success"; fi
        MESSAGE="✓ $COUNT |✗ $ERRORS |▲ $FAIL|➝ $SKIPPED"
        if [[ "$COUNT" -eq "0" ]]; then MESSAGE="✓ Success"; fi
    else
        COLOR="inactive"
        MESSAGE="no results"
    fi
    BADGE="https://img.shields.io/static/v1?logo=$LOGO&style=plastic&label=$LABEL&message=$MESSAGE&color=$COLOR"
    BADGE="${BADGE//' '/%20}"
    echo "[![$LABEL]($BADGE)]($URL)"
}

get_opts "$@"

URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
TMP="$ROOT_DIR/badges.tmp.local"
DIR=`basename $TEST_DIR`
FILE="$MARKDOWN_FILE"

echo -e "  * ${OK}URL${NC}: Current workflow is $URL"
echo -e "  * ${OK}FILE${NC}: Adding badges to $FILE"




if [[ -z "$CLOUD_REGION" ]]; then
    START="<!--$DIR-test-start-->"
    END="<!--$DIR-test-end-->"
else
    START="<!--$DIR-$CLOUD_REGION-test-start-->"
    END="<!--$DIR-$CLOUD_REGION-test-end-->"
fi
if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
    echo -e "  * ${INF}PULL_REQUEST${NC}: Badges will not updated within Pull Requests!"
else


    grep $START $FILE &> /dev/null
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo -e "  * ${INF}Add Badges${NC}: \n$START\n$END\n not found in $FILE, skipping Badges."
        #gha_notice "Add test Badges to $FILE" "Please add \n$START \n$END to $FILE"
    else
        MINWAIT=1
        MAXWAIT=45
        get_provider
        sleep $((MINWAIT+RANDOM % (MAXWAIT-MINWAIT))) # Random sleep Timer cause of Matrix Build
        # Unset extraheader from terraform
        git config --global --unset-all http."https://atc-github.azure.cloud.bmw/".extraheader
        git config user.name github-actions
        git config user.email github-actions@github.com
        BRANCH="${GITHUB_REF#refs/heads/}"
        echo -e "  * ${OK}Update local branch${NC}: Git fetch & merge $BRANCH"
        git config pull.rebase true
        git config fetch.prune true
        git fetch
        git merge --no-ff

        echo $START > $TMP
        if [[ "$ROOT_MODULE" == "true" ]]; then
            get_badge_url "$RESULTS_DIR/repo.junit.xml" "CNA repo" "git" >> $TMP
        fi
        get_badge_url "$RESULTS_DIR/base.junit.xml" "TF Base" "terraform" >> $TMP
        get_badge_url "$RESULTS_DIR/tflint.junit.xml" "TF Compliance (tflint)" "terraform" >> $TMP
        get_badge_url "$RESULTS_DIR/checkov.junit.xml" "Security (Checkov)" "terraform" >> $TMP
        if [[ ! "$ROOT_MODULE" == "true" ]]; then
            get_badge_url "$RESULTS_DIR/terraform.junit.xml" "TF Deploy" "terraform" >> $TMP
            get_badge_url "$RESULTS_DIR/inspec.junit.xml" "Inspec - $PROVIDER" "chef" >> $TMP
            # inspec-custom.junit.xml
            if [[ -f "$RESULTS_DIR/inspec-custom.junit.xml" ]]; then
                get_badge_url "$RESULTS_DIR/inspec-custom.junit.xml" "Inspec - Custom" "chef" >> $TMP
            fi
        fi
        echo $END >> $TMP
        sed -e '/'$START'/,/'$END'/!b' -e '/'$END'/!d;r '$TMP'' -e 'd' $FILE > tmp.local

        cp tmp.local $FILE
        #Commit
        echo -e "  * ${OK}Git commit${NC}: $FILE in $BRANCH"
        git commit $FILE -m "update badge urls: $GITHUB_EVENT_NAME, $FILE"
        git push
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo -e "  * ${INF}Push rejected${NC}: Local branch not up to date, will pull again !"
            git pull
            git push
            if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
                echo -e "  * ${ERR}Push rejected${NC}: Check github token permission !"
            fi
        fi
    fi
fi