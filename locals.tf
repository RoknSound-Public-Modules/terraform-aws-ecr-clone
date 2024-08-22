locals {
  base_tags = {
    "boc:tf_module_version" = local._module_version
    "boc:tf_module_name"    = local._module_name
    "boc:created_by"        = "terraform"
  }

  account_id          = var.account_id != "" ? var.account_id : data.aws_caller_identity.current.account_id
  _account_alias      = var.account_alias == null || var.account_alias == "" ? data.aws_iam_account_alias.current.account_alias : var.account_alias
  account_alias       = replace(local._account_alias, "do2", "do1")
  account_environment = data.aws_arn.current.partition == "aws-us-gov" ? "gov" : "ew"
}
