output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "aca_subnet_id" {
  value = azurerm_subnet.aca.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
