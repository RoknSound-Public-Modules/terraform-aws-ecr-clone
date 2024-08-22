variable "application_name" {
  description = "Appliication name, usually {org}-{project}, which is likely a prefix to the EKS cluster name"
  type        = string
}

variable "application_list" {
  description = "List of application repositories to create for /{application_name}/{image_name} for those not in image_config"
  type        = list(string)
  default     = []
}

variable "image_config" {
  description = "List of image configuration objects to copy from SOURCE to DESTINATION"
  type = list(object({
    name            = string,
    tag             = string,
    dest_path       = string,
    source_registry = string,
    source_image    = string,
    source_tag      = string,
    enabled         = bool,
  }))
  default = []
}
