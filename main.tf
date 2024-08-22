/*
* # About aws-ecr-copy-images
* This module will create ECR repositories with the prefix of {application_name} for the list of
* repositories in {application_list}.  This allows for a project to upload their images into
* /{application_name}/{sub_app}/{image}:{tag}.
*
* Also, if provided a list of source image configurations, it will download them from their location
* and upload them to the prefix of {application_name} followed by the {name} in the `image_config`
* object.
*
* # Usage
*
* ```hcl
* locals {
*   image_config = [
*     {
*       enabled         = true
*       dest_path       = null
*       name            = "openjdk-8"
*       source_image    = "ubi8/openjdk-8"
*       source_registry = "registry.access.redhat.com"
*       source_tag      = null
*       tag             = "latest"
*     },
*     {
*       enabled         = true
*       name            = "nginx-118"
*       dest_path       = null
*       source_image    = "ubi8/nginx-118"
*       source_registry = "registry.access.redhat.com"
*       source_tag      = null
*       tag             = "latest"
*     },
*     {
*       enabled         = true
*       name            = "nodejs-14"
*       dest_path       = null
*       source_image    = "ubi8/nodejs-14"
*       source_registry = "registry.access.redhat.com"
*       source_tag      = null
*       tag             = "latest"
*     },
*   ]
* }
* 
* module "images" {
*   source = "git@github.e.it.census.gov:terraform-modules/aws-ecr-copy-images.git"
* 
*   application_list = ["app1", "app2"]
*   application_name = "org-project"
*   image_config     = local.image_config
*   tags             = {}
* 
*   ### optional
*   ##  account_alias        = ""
*   ##  account_id           = ""
*   ##  destination_password = ""
*   ##  destination_username = ""
*   ##  override_prefixes    = {}
*   ##  region               = ""
*   ##  source_password      = ""
*   ##  source_username      = ""
* }
* ```
* 
* This creates the following ECR images
* 
* ```	
* Repository name URI Created at Tag immutability Scan on push Encryption type
* 
* org-project/app1	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/app1 August 22, 2022, 13:12:06 (UTC-04)	Enabled	Enabled	KMS 
* org-project/app2	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/app2 August 22, 2022, 13:12:06 (UTC-04)	Enabled	Enabled	KMS 
* org-project/nginx-118	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/nginx-118 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS
* org-project/nodejs-14	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/nodejs-14 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS 
* org-project/openjdk-8	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/openjdk-8 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS
* ```
* 
* # Caveats
* Currently, a destroy of the images (null_resources) does **NOT** remove the repository. That is a work in progress.
*/

locals {
  application_list = var.application_list
  ecr_repo_list    = { for app in local.application_list : app => format("%v/%v", var.application_name, app) }
}

#---
# craete reposs if list present
#---
resource "aws_ecr_repository" "apps_repos" {
  for_each = local.ecr_repo_list
  name     = each.value

  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(
    local.base_tags,
    tomap({
      "Name"        = format("ecr_%v/%v", var.application_name, each.key)
      "Environment" = "application"
    }),
  )
}

#---
# copy images
#---

data "aws_ecr_authorization_token" "token" {}

# ECR format
#  {application_name}/{image}:{ag}
# application_name = {org}-{program}
#   adsd-cumulus
#   dice-mojo
#   dice-centurion

locals {
  repo_parent_name = format("%v", var.application_name)
  region           = var.region == null ? data.aws_region.current.name : var.region

  account_ecr_registry = format("%v.dkr.ecr.%v.amazonaws.com", local.account_id, local.region)
  account_ecr          = format("%v/%v", local.account_ecr_registry, local.repo_parent_name)

  ##   images = { for i in var.image_config : format("%v#%v", i.name, i.tag) =>
  ##     merge(i, tomap({
  ##       key              = format("%v#%v", i.name, i.tag),
  ##       source_full_path = format("%v/%v:%v", i.source_registry, i.source_image, element(compact(concat([lookup(i, "source_tag", null)], [i.tag])), 0)),
  ##       dest_registry    = local.account_ecr_registry,
  ##       dest_full_path   = i.repo_path != null ? format("%v/%v/%v/%v:%v", local.account_ecr_registry, local.repo_parent_name, i.repo_path, i.name, i.tag) : format("%v/%v/%v:%v", local.account_ecr_registry, local.repo_parent_name, i.name, i.tag),
  ##       dest_repository  = i.repo_path != null ? format("%v/%v/%v", local.repo_parent_name, i.repo_path, i.name) : format("%v/%v", local.repo_parent_name, i.name),
  ##   })) }


  images = var.image_config != null ? { for i in var.image_config : format("%v#%v", i.name, i.tag) =>
    merge(i, tomap({
      key              = format("%v#%v", i.name, i.tag),
      source_full_path = format("%v/%v:%v", i.source_registry, i.source_image, element(compact(concat([lookup(i, "source_tag", null)], [i.tag])), 0)),
      dest_registry    = local.account_ecr_registry,
      dest_full_path   = format("%v/%v/%v:%v", local.account_ecr_registry, local.repo_parent_name, i.name, i.tag),
      dest_repository  = format("%v/%v", local.repo_parent_name, i.name),
  })) } : {}

  image_repos = { for k, v in local.images : k => format("%v/%v", local.account_ecr, v.name) }
}

resource "null_resource" "copy_images" {
  triggers = {
    region = local.region
  }
  for_each = { for image in local.images : image.key => image if image.enabled }

  provisioner "local-exec" {
    command = "${path.module}/bin/copy_image.sh"
    environment = {
      AWS_PROFILE          = var.profile
      AWS_REGION           = local.region
      SOURCE_IMAGE         = each.value.source_full_path
      DESTINATION_IMAGE    = each.value.dest_full_path
      SOURCE_USERNAME      = var.source_username == null ? "" : var.source_username
      SOURCE_PASSWORD      = var.source_password == null ? "" : var.source_password
      DESTINATION_USERNAME = var.destination_username == null ? data.aws_ecr_authorization_token.token.user_name : var.destination_username
      DESTINATION_PASSWORD = var.destination_password == null ? data.aws_ecr_authorization_token.token.password : var.destination_password
    }
  }
  depends_on = [
    aws_ecr_repository.apps_repo
  ]
}
