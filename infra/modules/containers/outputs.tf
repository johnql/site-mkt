output "aca_identity_principal_id" {
  value = azurerm_user_assigned_identity.aca.principal_id
}

output "aca_environment_name" {
  value = azurerm_container_app_environment.main.name
}

output "site_fqdn" {
  value = azurerm_container_app.site.ingress[0].fqdn
}

output "api_fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}
