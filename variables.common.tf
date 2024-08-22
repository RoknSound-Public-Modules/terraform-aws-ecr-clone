#---
# account info
#---
variable "account_id" {
  description = "AWS Account ID (default will pull from current user)"
  type        = string
  default     = ""
}

variable "account_alias" {
  description = "AWS Account Alias"
  type        = string
  default     = ""
}

variable "override_prefixes" {
  description = "Override built-in prefixes by component. This should be used primarily for common infrastructure things"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "AWS Tags to apply to appropriate resources"
  type        = map(string)
  default     = {}
}
