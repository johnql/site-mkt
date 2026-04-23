# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

POC for provisioning Azure infrastructure via Terraform to host a containerized .NET 9 marketing site. The pattern is intended to become a reusable template for other teams. The `infra/` directory is currently empty — Terraform code is the primary pending deliverable.

## Local Development

```bash
docker-compose up        # Run the full stack (site, api, redis, sql server)
http://localhost:8881    # Access the site
```

The site is the only service exposed externally (8881 → 8080). Api, redis, and database are internal only.

## Build

```bash
docker build -f Dockerfile.site -t marketing-site .
docker build -f Dockerfile.api  -t marketing-api .
dotnet restore && dotnet build -c Release   # without Docker
```

## Architecture

```
Browser → Site (:8080) → Redis (cache, 5s TTL)
                       → Api (:8080) → SQL Server
```

- **Site** serves HTML. Calls Api for datetime, caches in Redis (5s TTL), renders response.
- **Api** reads datetime from SQL Server, returns JSON.
- No MVC controllers — all HTTP handling via Minimal APIs `RouteHandler` pattern.
- Services registered via `DependencyInjection.cs` extension methods in each project.
- Data models use C# `record` types. Redis uses a `Lazy<ConnectionMultiplexer>` singleton.

## Required Environment Variables

**Site:** `REDIS_CONNECTION_STRING`, `MarketingApi__BaseUrl`
**Api:** `DB_CONNECTION_STRING`

docker-compose.yaml provides working local values.

## Code Conventions

- Interfaces prefixed with `I` (e.g. `IHelloWorldService`, `ICacheService`)
- Route handlers named `{Feature}RouteHandler`
- C# 11+ primary constructor syntax for DI
- All services resolved through DI — no static access

## CI/CD

`.github/workflows/build.yml` builds both Docker images on push/PR to `main`. No push or deployment configured yet. No test suite exists.

## Infrastructure (Pending)

`infra/` is empty. Terraform deliverable must provision Azure resources for the two containers, Redis, and SQL. Key constraints:
- Traffic window 10 AM–8 PM EST (burst capacity needed)
- SQL database holds sensitive data (security-critical)
- Must be a reusable template for other teams
