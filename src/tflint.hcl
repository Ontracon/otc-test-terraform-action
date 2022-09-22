config {
  module              = true
  disabled_by_default = false
  plugin_dir = "~/.tflint.d/plugins"
}

plugin "aws" {
  enabled = false
}

plugin "azurerm" {
    enabled = false
}

plugin "cna" {
 enabled = false
 }
  
rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style = "flexible"
}

rule "terraform_module_version" {
  enabled = true
  exact = false
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

