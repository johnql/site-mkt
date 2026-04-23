
# Problem Statement

The marketing department is launching a new promotional landing page that displays a 'hello world' message with the current date, pulled from a sensitive SQL database, which is cached for 5 seconds. They expect significant traffic from 10:00 AM to 8:00 PM EST, especially during the first few days of the campaign.

Your task is to use Terraform to provision the Azure infrastructure to support this application. You are responsible for designing the full solution architecture to meet the requirements of a production environment.

### Strategic Context

This deployment is more than a one-time project. It is a Proof of Concept (POC) designed to establish a reusable and standardized pattern for deploying similar containerized applications within the organization. A successful outcome will serve as a template, allowing other teams to quickly adopt a secure and scalable architecture for their own initiatives.

## Requirements

- **Use Terraform** to provision all Azure infrastructure
- **Deploy to Azure** (your choice of services)

## Deliverables

A repository link containing a git repository with your Terraform code, and a readme file with instructions for deployment. The README should also include a brief overview of your design choices.


# Further Information

This site is the first version of the Hello World Site. It is composed of two projects `Site` and `Api`.

## Requirements to run the site

The Site container expects the following environment variables:
- `REDIS_CONNECTION_STRING` to contain a connection string for a Redis server.
- `MarketingApi__BaseUrl` to contain the base URL of the Api project.

The Api container expects the following environment variables:
- `DB_CONNECTION_STRING` to contain a connection string for a SQL Server.

The solution also contains a `docker-compose.yml` file that can be used to run the site locally using Docker.

---

## Deployment Guide

## Architecture

```text
Internet
   │
   ▼
Azure Container Apps (external ingress)
   ca-site-mkt-prod  (:8080)
   │                │
   ▼                ▼
Redis Cache      ca-api-mkt-prod  (internal only, :8080)
(private         │
 endpoint)       ▼
              Azure SQL Server
              (private endpoint)
```

All traffic between containers is internal to the Container App Environment VNet. SQL and Redis are accessible only via private endpoints — no public internet exposure.

**Resources provisioned:**

| Resource | Name Pattern | Notes |
|---|---|---|
| Resource Group | `rg-{app}-{env}-{location}` | All resources except SQL server |
| VNet | `vnet-{app}-{env}` | `10.0.0.0/16` |
| ACA Subnet | `snet-aca` | `10.0.0.0/21`, delegated to `Microsoft.App/environments` |
| Private Endpoint Subnet | `snet-pe` | `10.0.8.0/24` |
| Container Registry | pre-created (bootstrap) | Shared ACR for all environments |
| Container App Environment | `cae-{app}-{env}` | VNet-integrated |
| Container App — Site | `ca-site-{app}-{env}` | External ingress, 1–10 replicas |
| Container App — Api | `ca-api-{app}-{env}` | Internal ingress only, 1–10 replicas |
| Azure SQL Server | `sql-{app}-{env}-{suffix}` | Deployed in configurable region |
| Azure SQL Database | `marketingdb` | General Purpose serverless |
| Azure Cache for Redis | `redis-{app}-{env}-{suffix}` | Standard C1, private endpoint |
| Key Vault | `kv-{app}-{env}-{suffix}` | Stores DB + Redis connection strings |
| User-Assigned Identity | `id-aca-{app}-{env}` | AcrPull + Key Vault Get/List |
| Private DNS Zones | `privatelink.database.windows.net`, `privatelink.redis.cache.windows.net` | VNet-linked |

## Design Decisions

**Azure Container Apps** — Chosen over AKS for this workload because the traffic pattern (10 AM–8 PM burst) maps perfectly to HTTP-based autoscaling without the overhead of managing Kubernetes. Scale rules fire at 20 concurrent requests, scaling from 1 to 10 replicas. Min replicas = 1 keeps cold-start latency out of the picture during business hours.

**Private endpoints for SQL and Redis** — Both data stores are completely isolated from the public internet. The ACA environment runs inside a VNet; private DNS zones resolve `*.privatelink` hostnames so containers connect over the private network without any credentials in image layers or environment variables.

**Key Vault + Managed Identity** — Connection strings are stored as Key Vault secrets and mounted directly into Container Apps via the `secret` block. The user-assigned identity (`id-aca-mkt-prod`) holds both the `AcrPull` role on ACR and a Key Vault access policy. No static credentials or SAS tokens anywhere.

**Random suffix on SQL/Redis names** — Azure SQL server names and Redis cache names are globally unique across all Azure tenants. The `random_string` resource ensures conflict-free names on every new deployment of the template.

**`sql_location` as a separate variable** — Azure SQL provisioning availability varies by subscription type and region. Decoupling `sql_location` from `location` lets teams pick the nearest unrestricted region without moving the rest of the stack.

**Terraform remote state in Azure Blob Storage** — State is stored in a dedicated storage account (`stmktterraformstate`) with versioning enabled. Teams adapting this template should create their own backend storage account during bootstrap.

**Reusability** — The entire stack is parameterised via `variables.tf`. To deploy a second environment, change `app_name`, `environment`, and optionally `location`. All resource names derive from `local.prefix = "${var.app_name}-${var.environment}"`.

## Prerequisites

- Azure CLI (`az`) authenticated to the target subscription
- Terraform >= 1.5
- Docker (for building and pushing images)
- Bash (WSL or Git Bash on Windows)

## One-Time Bootstrap

Run once per subscription to create the ACR and Terraform state backend:

```bash
cd infra/scripts
chmod +x bootstrap.sh
./bootstrap.sh
```

The script:
1. Registers required Azure resource providers
2. Creates the Terraform remote state storage account and container
3. Creates Azure Container Registry `acrmktprodeastus`
4. Builds both Docker images and pushes them to ACR

## Deploy Infrastructure

```bash
cd infra

# Copy and populate variables
cp terraform.tfvars.example terraform.tfvars   # if using the example file
# Edit terraform.tfvars with your subscription_id and sql_admin_password

terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

**Key variables in `terraform.tfvars`:**

```hcl
subscription_id    = "<your-subscription-id>"
location           = "eastus"          # Region for most resources
sql_location       = "centralus"       # Region for SQL Server (may differ)
environment        = "prod"
app_name           = "mkt"
acr_name           = "acrmktprodeastus"
sql_admin_username = "sqladmin"
sql_admin_password = "<strong-password>"
redis_sku          = "Standard"
redis_family       = "C"
redis_capacity     = 1
```

> **Note on `sql_location`:** Azure SQL provisioning is restricted in some regions for certain subscription types. If you hit a `ProvisioningDisabled` error, try `centralus`, `canadacentral`, or `northeurope`.

## Verify the Deployment

```bash
cd infra

# Get the live URL
terraform output site_url

# Health check
curl https://<site_url>/health

# Full page load (should render HTML with current date/time)
curl https://<site_url>
```

Expected: HTTP 200 with an HTML page showing "Hello World" and the current datetime from SQL.

## Adapting for Another Team

1. Fork this repository
2. Run bootstrap with a different `acr_name` (or reuse an existing ACR)
3. In `terraform.tfvars`, set `app_name` to your team's identifier (e.g. `payments`)
4. All resources will be namespaced under `payments-prod-*` with no conflicts

## Local Development

```bash
docker-compose up        # Runs site, api, redis, and SQL Server locally
# Site accessible at http://localhost:8881
```

## CI/CD

`.github/workflows/build.yml` builds both Docker images on push to `main`. Extend it to push to ACR after a successful build:

```yaml
- name: Push to ACR
  run: |
    az acr login --name $ACR_NAME
    docker push $ACR_NAME.azurecr.io/marketing-site:latest
    docker push $ACR_NAME.azurecr.io/marketing-api:latest
```

After pushing new images, trigger a Container App revision by running `terraform apply` or using the Azure CLI:

```bash
az containerapp update --name ca-site-mkt-prod --resource-group rg-mkt-prod-eastus \
  --image acrmktprodeastus.azurecr.io/marketing-site:latest
```

### Weakest Points in the Current Solution

**Security — SQL password is a static credential.** The connection string stored in Key Vault contains a username/password. The correct pattern for Azure SQL is Azure Active Directory authentication with the ACA managed identity, which eliminates the password entirely. This is a meaningful gap for a "security-critical" data store.

**Cost — Redis Standard C1 is always-on.** Redis does not scale to zero. At ~$55/month for Standard C1, it is the dominant cost in this stack at low traffic. For a promotional site with a 10-hour daily traffic window, consider a scheduled script that scales Redis down at 8 PM EST and up at 10 AM, or evaluate whether the 5-second TTL cache is worth a dedicated Redis tier at all (an in-memory cache in the Site container would suffice at low scale).

**Reliability — Single availability zone.** No AZ pinning is configured anywhere. Azure Container Apps do distribute replicas across zones in supported regions, but SQL and Redis are on default zone-redundant settings only on higher service tiers. For production, SQL should be on at least `GeneralPurpose` with zone-redundant backup, and Redis Standard already includes replication.

**Observability — none.** The site is live with no alerts, no dashboards, and no structured logging correlation between Site → Api → SQL. A production incident would require raw log queries from the start.

# optimization opportunities

**Already optimized:**

    Redis 5s TTL shields SQL from ~99% of peak traffic
    ACA scales to zero outside 10AM–8PM, eliminating idle cost
    Private Endpoints keep SQL/Redis off the public internet

**Top optimization to add:**

    ACA scheduled scaling — keep min 1 replica during 10AM–8PM to avoid cold starts during the campaign burst. Highest impact, near-zero cost.

**Main offsets (tradeoffs):**

    VNet + Private Endpoints = ~$15+/month but required given sensitive SQL data
    Redis Standard (HA) vs Basic C0 — double the cost, but Basic is risky for production
    Azure SQL Serverless saves cost but has cold-start risk (mitigated by Redis cache)
    Front Door adds performance at edge but adds $35+/month — skip for POC