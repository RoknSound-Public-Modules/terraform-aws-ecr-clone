# locals {
#   az_list       = data.aws_availability_zones.zones.names
#   az_count      = length(local.az_list)
#   az_count_list = range(local.az_count)
# }

data "aws_availability_zones" "zones" {
  state = "available"
}

data "aws_availability_zone" "zone" {
  for_each = toset(data.aws_availability_zones.zones.names)
  state    = "available"
  name     = each.key
}

output "availability_zone_names" {
  description = "VPC Availability zone name list (3)"
  value       = data.aws_availability_zones.zones.names
}

output "availability_zone_ids" {
  description = "VPC Availability zone id list (3)"
  value       = data.aws_availability_zones.zones.zone_ids
}

output "availability_zone_suffixes" {
  description = "VPC Availability zone suffix list (3)"
  value       = [for k, v in data.aws_availability_zone.zone : v.name_suffix]
}
