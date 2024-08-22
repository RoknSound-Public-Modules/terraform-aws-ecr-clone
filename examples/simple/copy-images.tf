module "images" {
  source = "git@github.e.it.census.gov:terraform-modules/aws-ecr-copy-images.git"

  application_list = ["app1", "app2"]
  application_name = "org-project"
  image_config     = var.image_config
  tags             = {}

  ### optional
  ##  account_alias        = ""
  ##  account_id           = ""
  ##  destination_password = ""
  ##  destination_username = ""
  ##  override_prefixes    = {}
  ##  region               = ""
  ##  source_password      = ""
  ##  source_username      = ""
}

