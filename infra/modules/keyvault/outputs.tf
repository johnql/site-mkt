output "keyvault_id" {
  value = azurerm_key_vault.main.id
}

output "db_secret_uri" {
  value = azurerm_key_vault_secret.db_connection_string.versionless_id
}

output "redis_secret_uri" {
  value = azurerm_key_vault_secret.redis_connection_string.versionless_id
}
