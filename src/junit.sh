#!/bin/bash
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
########################################################################################################################
# Generate Junit XML File from bash
# source "$SCRIPT_DIRECTORY/junit.sh"
# Usage:
# 1. Init Junit File
#    junit_init "Base Repo Tests"
# 2. add Test OK
#    junit_add_ok "Test_OK"
# 3. GRAB OUTPUT of command
#    df -h | tee -i ./OUT.txt >/dev/null
#    OUT=`cat ./OUT.txt`
# 4. ADD FAILURE
#    junit_add_fail "Test_FAIL" "Test for failures" "$OUT"
# 5. ADD ERROR
#    junit_add_error "Test_ERROR" "test for errors" "$OUT"
# 6. RENDER JUNIT FILE
#    junit_render "$RESULTS_DIR/test.xml"
#
########################################################################################################################
RESULTS_DIR="$ROOT_DIR/.results"
UNIT_RESULTS="$RESULTS_DIR/tf-validate-result.xml"


function junit_init {
    err=0 fail=0 total=0 CASES="$SCRIPT_DIRECTORY/CASES.local"
    dir=$(basename $ROOT_DIR)
    JUNIT_TEST_NAME=$1
    JUNIT_TESTS=`basename $0`
    START=$(date +%s)
}

function junit_timestamp {
    date "+%Y-%m-%dT%H:%M:%S"
}

function junit_duration {
    STOP=$(date +%s)
    DURATION=$(($STOP - $START))
    echo $DURATION
}

function junit_header {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites disabled="" errors="$err" failures="$fail" name="$JUNIT_TEST_NAME" tests="$total" time="$(junit_duration)" timestamp="$(junit_timestamp)" >
<testsuite name="$JUNIT_TEST_NAME"  tests="$total" disabled="0" errors="$err" failures="$fail" hostname="$HOSTNAME" >
EOF
}
function junit_add_ok {
    OK_NAME=$1
    total=`expr $total + 1`
    cat <<EOF >> $CASES
<testcase name="$OK_NAME" classname="$dir">
</testcase>
EOF
}

function junit_add_error {
    ERR_NAME=$1
    ERR_MESSAGE=$2
    err=`expr $err + 1`
    total=`expr $total + 1`

    cat <<EOF >> $CASES
<testcase name="$ERR_NAME" classname="$dir">
 <error message="$ERR_MESSAGE" type="">
  $ERR_MESSAGE
 </error>
</testcase>
EOF
}

function junit_add_fail {
    FAIL_NAME=$1
    FAIL_MESSAGE=$2
    fail=`expr $fail + 1`
    total=`expr $total + 1`
    cat <<EOF >> $CASES
<testcase name="$FAIL_NAME" classname="$dir">
 <failure message="$FAIL_MESSAGE" type="">
  $FAIL_MESSAGE
 </failure>
   </testcase>
EOF
}

function junit_footer {
    cat <<EOF
</testsuite>
</testsuites>
EOF
}

function junit_render {
    FILE=$1
    junit_header > $FILE
    cat $CASES >> $FILE
    junit_footer >> $FILE
    rm $CASES
}


