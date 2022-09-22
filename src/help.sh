#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------
# Help for shell scripts
# ---------------------------------------------------------------------------------------------------------------------
help()
{
    echo "# ---------------------------------------"
    echo "# Help for `basename $0` "
    echo "# ---------------------------------------"
    echo
    echo "The following parameters are supported. The specification of the 'd' parameter is mandatory."
    echo
    echo "-x Debug Information"
    echo "-o ""true"" Enable output for tests "
    echo "-m ""true"" is a root module"
    echo "-d Terraform working directory for testing"
    echo "-t Directory which contains test fixtures (Terraform TFVARS files)"
    echo "-r AWS Region or Azure location to test if TEST_DIR\terraform.CLOUD_REGION.tfvars exists"
    echo "-b Backend File to use"
    echo "-a Auto Create Backend Config & State (CNA)"
}