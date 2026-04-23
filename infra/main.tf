locals {
  prefix = "${var.app_name}-${var.environment}"
  tags = {
    environment = var.environment
    app         = var.app_name
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}-${var.location}"
  location = var.location
  tags     = local.tags
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name

  depends_on = [azurerm_resource_group.main]
}

module "network" {
  source              = "./modules/network"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "data" {
  source              = "./modules/data"
  prefix              = local.prefix
  location            = var.location
  sql_location        = var.sql_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  sql_admin_username        = var.sql_admin_username
  sql_admin_password        = var.sql_admin_password
  redis_sku                 = var.redis_sku
  redis_family              = var.redis_family
  redis_capacity            = var.redis_capacity
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  vnet_id                   = module.network.vnet_id
}

module "keyvault" {
  source              = "./modules/keyvault"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  sql_connection_string   = module.data.sql_connection_string
  redis_connection_string = module.data.redis_connection_string
  aca_principal_id        = module.containers.aca_identity_principal_id
}

module "containers" {
  source              = "./modules/containers"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  acr_login_server        = data.azurerm_container_registry.acr.login_server
  acr_id                  = data.azurerm_container_registry.acr.id
  aca_subnet_id           = module.network.aca_subnet_id
  keyvault_id             = module.keyvault.keyvault_id
  db_secret_uri           = module.keyvault.db_secret_uri
  redis_secret_uri        = module.keyvault.redis_secret_uri
}
