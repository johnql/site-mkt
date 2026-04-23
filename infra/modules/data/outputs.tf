output "sql_connection_string" {
  sensitive = true
  value     = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=${azurerm_mssql_database.main.name};User Id=${var.sql_admin_username};Password=${var.sql_admin_password};TrustServerCertificate=True;"
}

output "redis_connection_string" {
  sensitive = true
  value     = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},password=${azurerm_redis_cache.main.primary_access_key},ssl=True,abortConnect=False"
}
