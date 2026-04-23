variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "sql_connection_string" {
  type      = string
  sensitive = true
}
variable "redis_connection_string" {
  type      = string
  sensitive = true
}
variable "aca_principal_id" { type = string }
