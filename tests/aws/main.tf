module "common" {
  source       = "git::https://github.com/Ontracon/tfm-cloud-commons.git?ref=1.0.0"
  cloud_region = "eu-central-1"
  global_config = {
    customer_prefix = "OTC" # Can also be an empty String "". Empty string results in a random prefix!
    env             = "DEV"
    project         = "Common"
    application     = "10-Simple"
    costcenter      = "0815"
  }

  password_create = false
}

resource "random_pet" "name" {
  length = 3
}

