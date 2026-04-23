variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all resources"
}

variable "sql_location" {
  type        = string
  default     = "centralus"
  description = "Azure region for SQL Server (eastus/eastus2/westus2 have provisioning restrictions on some subscriptions)"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name (prod, staging, dev)"
}

variable "app_name" {
  type        = string
  default     = "mkt"
  description = "Short application name used in resource naming"
}

variable "acr_name" {
  type        = string
  default     = "acrmktprodeastus"
  description = "Azure Container Registry name (pre-created in bootstrap)"
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "SQL Server administrator password"
}

variable "sql_admin_username" {
  type        = string
  default     = "sqladmin"
  description = "SQL Server administrator username"
}

variable "redis_sku" {
  type    = string
  default = "Standard"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 1
}
