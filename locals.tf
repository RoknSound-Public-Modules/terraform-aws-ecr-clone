locals {
  base_tags = {
    "boc:tf_module_version" = local._module_version
    "boc:tf_module_name"    = local._module_name
    "boc:created_by"        = "terraform"
  }

  account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current.account_id
}
