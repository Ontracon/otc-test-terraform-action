# otc-test-action

Chef inspec:
curl <https://omnitruck.chef.io/install.sh> | sudo bash -s -- -P inspec

tflint:
curl -s <https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh> | bash

brew install tflint
tflint --version
brew install checkov
checkov --version
brew install terraform
terraform --version
