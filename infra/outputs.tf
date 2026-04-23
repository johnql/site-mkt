output "site_url" {
  description = "Public URL of the marketing site"
  value       = "https://${module.containers.site_fqdn}"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = data.azurerm_container_registry.acr.login_server
}

output "aca_environment_name" {
  value = module.containers.aca_environment_name
}
