# About aws-ecr-copy-images
This module will create ECR repositories with the prefix of {application\_name} for the list of
repositories in {application\_list}.  This allows for a project to upload their images into
/{application\_name}/{sub\_app}/{image}:{tag}.

Also, if provided a list of source image configurations, it will download them from their location
and upload them to the prefix of {application\_name} followed by the {name} in the `image_config`
object.

# Usage

```hcl
locals {
  image_config = [
    {
      enabled         = true
      dest_path       = null
      name            = "openjdk-8"
      source_image    = "ubi8/openjdk-8"
      source_registry = "registry.access.redhat.com"
      source_tag      = null
      tag             = "latest"
    },
    {
      enabled         = true
      name            = "nginx-118"
      dest_path       = null
      source_image    = "ubi8/nginx-118"
      source_registry = "registry.access.redhat.com"
      source_tag      = null
      tag             = "latest"
    },
    {
      enabled         = true
      name            = "nodejs-14"
      dest_path       = null
      source_image    = "ubi8/nodejs-14"
      source_registry = "registry.access.redhat.com"
      source_tag      = null
      tag             = "latest"
    },
  ]
}

module "images" {
  source = "git@github.e.it.census.gov:terraform-modules/aws-ecr-copy-images.git"

  application_list = ["app1", "app2"]
  application_name = "org-project"
  image_config     = local.image_config
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
```

This creates the following ECR images

```	
Repository name URI Created at Tag immutability Scan on push Encryption type

org-project/app1	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/app1 August 22, 2022, 13:12:06 (UTC-04)	Enabled	Enabled	KMS
org-project/app2	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/app2 August 22, 2022, 13:12:06 (UTC-04)	Enabled	Enabled	KMS
org-project/nginx-118	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/nginx-118 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS
org-project/nodejs-14	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/nodejs-14 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS
org-project/openjdk-8	817869416306.dkr.ecr.us-gov-east-1.amazonaws.com/org-project/openjdk-8 August 22, 2022, 12:43:57 (UTC-04)	Enabled	Enabled	KMS
```

# Caveats
Currently, a destroy of the images (null\_resources) does **NOT** remove the repository. That is a work in progress.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.apps_repos](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [null_resource.copy_images](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_arn.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/arn) | data source |
| [aws_availability_zone.zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_availability_zones.zones](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_iam_account_alias.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_account_alias) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | AWS Account Alias | `string` | `""` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account ID (default will pull from current user) | `string` | `""` | no |
| <a name="input_application_list"></a> [application\_list](#input\_application\_list) | List of application repositories to create for /{application\_name}/{image\_name} for those not in image\_config | `list(string)` | `[]` | no |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | Appliication name, usually {org}-{project}, which is likely a prefix to the EKS cluster name | `string` | n/a | yes |
| <a name="input_destination_password"></a> [destination\_password](#input\_destination\_password) | OCI destination repository password | `string` | `null` | no |
| <a name="input_destination_username"></a> [destination\_username](#input\_destination\_username) | OCI destination repository username | `string` | `null` | no |
| <a name="input_image_config"></a> [image\_config](#input\_image\_config) | List of image configuration objects to copy from SOURCE to DESTINATION | <pre>list(object({<br>    name            = string,<br>    tag             = string,<br>    dest_path       = string,<br>    source_registry = string,<br>    source_image    = string,<br>    source_tag      = string,<br>    enabled         = bool,<br>  }))</pre> | `[]` | no |
| <a name="input_override_prefixes"></a> [override\_prefixes](#input\_override\_prefixes) | Override built-in prefixes by component. This should be used primarily for common infrastructure things | `map(string)` | `{}` | no |
| <a name="input_profile"></a> [profile](#input\_profile) | AWS Profile Name, used generating key rotation file | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region in which to create the ECR repositories (default of current region) | `string` | `null` | no |
| <a name="input_source_password"></a> [source\_password](#input\_source\_password) | OCI source repository password | `string` | `null` | no |
| <a name="input_source_username"></a> [source\_username](#input\_source\_username) | OCI source repository username | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | AWS Tags to apply to appropriate resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zone_ids"></a> [availability\_zone\_ids](#output\_availability\_zone\_ids) | VPC Availability zone id list (3) |
| <a name="output_availability_zone_names"></a> [availability\_zone\_names](#output\_availability\_zone\_names) | VPC Availability zone name list (3) |
| <a name="output_availability_zone_suffixes"></a> [availability\_zone\_suffixes](#output\_availability\_zone\_suffixes) | VPC Availability zone suffix list (3) |
| <a name="output_images"></a> [images](#output\_images) | Final full merge of images with extra details |
=======
# terraform-aws-ecr-clone
Terraform Workspace
