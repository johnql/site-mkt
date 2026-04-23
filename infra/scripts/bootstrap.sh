#!/usr/bin/env bash
# Run once before terraform init to create remote state backend and ACR.
# Usage: bash infra/scripts/bootstrap.sh
set -euo pipefail

LOCATION="eastus"
STATE_RG="rg-mkt-tfstate"
STATE_SA="stmktterraformstate"
STATE_CONTAINER="tfstate"
APP_RG="rg-mkt-prod-eastus"
ACR_NAME="acrmktprodeastus"

echo "==> Registering required resource providers..."
for ns in Microsoft.Storage Microsoft.ContainerRegistry Microsoft.App \
          Microsoft.Sql Microsoft.Cache Microsoft.KeyVault Microsoft.Network; do
  az provider register --namespace "$ns" --wait
done

echo "==> Creating Terraform state resource group..."
az group create --name "$STATE_RG" --location "$LOCATION" --output none

echo "==> Creating Terraform state storage account..."
az storage account create \
  --name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none

echo "==> Creating tfstate blob container..."
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_SA" \
  --auth-mode login \
  --output none

echo "==> Creating application resource group..."
az group create --name "$APP_RG" --location "$LOCATION" --output none

echo "==> Creating Azure Container Registry..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$APP_RG" \
  --sku Basic \
  --admin-enabled true \
  --output none

echo "==> Logging in to ACR..."
az acr login --name "$ACR_NAME"

echo "==> Building and pushing Docker images..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

docker build -f "$REPO_ROOT/Dockerfile.site" -t "$ACR_NAME.azurecr.io/marketing-site:latest" "$REPO_ROOT"
docker push "$ACR_NAME.azurecr.io/marketing-site:latest"

docker build -f "$REPO_ROOT/Dockerfile.api" -t "$ACR_NAME.azurecr.io/marketing-api:latest" "$REPO_ROOT"
docker push "$ACR_NAME.azurecr.io/marketing-api:latest"

echo ""
echo "Bootstrap complete. Run the following to initialise Terraform:"
echo "  cd infra && terraform init"
