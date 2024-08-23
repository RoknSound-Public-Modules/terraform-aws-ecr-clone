
locals {
  ecr_repo_list = { for app in var.application_list : app => format("%v/%v", var.application_name, app) }
}

resource "aws_ecr_repository" "apps_repos" {
  for_each = local.ecr_repo_list
  name     = each.value

  image_tag_mutability = var.image_tag_mutability
  image_scanning_configuration {
    scan_on_push = var.image_scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
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


locals {
  destination_username = var.destination_username == null ? data.aws_ecr_authorization_token.token.user_name : var.destination_username
  destination_password = var.destination_password == null ? data.aws_ecr_authorization_token.token.password : var.destination_password
  repo_parent_name     = format("%v", var.application_name)
  region               = var.region == null ? data.aws_region.current.name : var.region

  account_ecr_registry = format("%v.dkr.ecr.%v.amazonaws.com", local.account_id, local.region)
  account_ecr          = format("%v/%v", local.account_ecr_registry, local.repo_parent_name)

  images = { for i in var.image_config : format("%v#%v", i.name, i.tag) =>
    merge(i, tomap({
      name             = i.name,
      tag              = i.tag,
      key              = format("%v#%v", i.name, i.tag),
      source_full_path = format("%v/%v:%v", i.source_registry, i.source_image, lookup(i, "source_tag", i.tag)),
      dest_full_path   = format("%v/%v/%v:%v", local.account_ecr_registry, local.repo_parent_name, i.name, i.tag),
  })) }
  commands = {
    for image in local.images : image.key => concat(
      ["skopeo copy --insecure-policy"],
      var.source_username == null ? ["--src-creds=${var.source_username}:${var.source_password}"] : ["--src-no-creds"],
      var.source_insecure ? ["--src-tls-verify=false"] : ["--src-tls-verify=true"],
      var.destination_username == null ? ["--dest-creds=${local.destination_username}:${local.destination_password}"] : ["--dest-no-creds"],
      var.destination_insecure ? ["--dest-tls-verify=false"] : ["--dest-tls-verify=true"],
      ["docker://${image.source_full_path}", "docker://${image.dest_full_path}"]
    )
  }
}


resource "aws_ecr_repository" "image_repos" {
  for_each = local.images
  name     = "${local.repo_parent_name}/${each.value.name}"

  image_tag_mutability = var.image_tag_mutability
  image_scanning_configuration {
    scan_on_push = var.image_scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
  }

  tags = merge(
    local.base_tags,
    tomap({
      "Name"        = format("ecr_%v/%v", var.application_name, each.value.name)
      "Environment" = "application"
    }),
  )
}


resource "null_resource" "copy_images" {
  for_each = local.images

  triggers = {
    image = each.value.name
  }

  provisioner "local-exec" {
    command = join(" ", local.commands[each.key])
  }
  depends_on = [
    aws_ecr_repository.apps_repos,
    aws_ecr_repository.image_repos
  ]
}
