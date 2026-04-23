variable "prefix" { type = string }
variable "location" { type = string }
variable "sql_location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "sql_admin_username" { type = string }
variable "sql_admin_password" {
  type      = string
  sensitive = true
}
variable "redis_sku" { type = string }
variable "redis_family" { type = string }
variable "redis_capacity" { type = number }
variable "private_endpoint_subnet_id" { type = string }
variable "vnet_id" { type = string }
