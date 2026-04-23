resource "azurerm_user_assigned_identity" "aca" {
  name                = "id-aca-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}

resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${var.prefix}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = var.aca_subnet_id
  internal_load_balancer_enabled = false
  tags                           = var.tags

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

# ── marketing-api (internal only) ───────────────────────────────────────────
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.aca.id
  }

  secret {
    name                = "db-connection-string"
    key_vault_secret_id = var.db_secret_uri
    identity            = azurerm_user_assigned_identity.aca.id
  }

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "marketing-api"
      image  = "${var.acr_login_server}/marketing-api:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "DB_CONNECTION_STRING"
        secret_name = "db-connection-string"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }
    }

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = "20"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}

# ── marketing-site (external) ────────────────────────────────────────────────
resource "azurerm_container_app" "site" {
  name                         = "ca-site-${var.prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.aca.id
  }

  secret {
    name                = "redis-connection-string"
    key_vault_secret_id = var.redis_secret_uri
    identity            = azurerm_user_assigned_identity.aca.id
  }

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "marketing-site"
      image  = "${var.acr_login_server}/marketing-site:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "REDIS_CONNECTION_STRING"
        secret_name = "redis-connection-string"
      }

      env {
        name  = "MarketingApi__BaseUrl"
        value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }
    }

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = "20"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [azurerm_container_app.api]
}
