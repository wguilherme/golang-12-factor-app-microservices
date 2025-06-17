# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Go microservices monorepo using Go Workspaces for 12-factor app principles. The project contains multiple microservices (`worker_flow` and `worker_post`) that are independently deployable with shared common code.

## Architecture

- **Go Workspaces**: Multi-module workspace with `go.work` file
- **Services**: Each service in `/services/{service}/` with own `go.mod`
- **Shared Code**: Common functionality in `/shared/` module
- **Tools**: Development tools in `/tools/` module
- **Containerization**: Multi-stage Docker builds with debug/prod targets
- **Security**: Integrated security scanning with gosec, trivy, govulncheck, and gitleaks

## Workspace Structure

```
├── go.work (workspace root)
├── services/
│   ├── worker_flow/ (independent module)
│   └── worker_post/ (independent module)
├── shared/ (shared code module)
└── tools/ (development tools module)
```

## Development Commands

### Workspace Operations
- `make workspace-sync` - Sync workspace dependencies
- `make workspace-use` - List current workspace modules

### Basic Operations
- `make run` - Run a service (default worker_flow)
- `make run app=worker_post` - Run specific service
- `make test` - Run tests for all modules with coverage
- `make test-service app=worker_flow` - Test specific service
- `make build` - Build specific service
- `make build-all` - Build all services
- `make debug` - Start debugger on port 2345

### Docker Operations
- `make up` - Start all services with Docker Compose
- `make up-dev` - Start in debug mode
- `make up-prod` - Start in production mode
- `make down` - Stop all services
- `make logs` - View logs for specific service
- `make logs-all` - View all service logs

### Security Scanning
- `make security` - Run all security checks
- `make gosec` - Go security checker
- `make trivy` - Container vulnerability scanner
- `make govulncheck` - Go vulnerability checker
- `make gitleaks` - Secret detection

## Configuration

Services use environment variables for configuration:
- `WORKER_FLOW_PORT` (default: 8080)
- `WORKER_POST_PORT` (default: 8081)
- Configuration via `.env` files

## Service Structure

Each microservice provides:
- `/health/live` - Liveness probe
- `/health/ready` - Readiness probe
- JSON response format with status, service name, and timestamp

## Dependencies

- Go 1.23.6 with Go Workspaces
- **Shared module**: github.com/go-chi/chi/v5 for HTTP routing
- **Services**: Independent modules consuming shared code
- **Tools**: Development tools (gosec, delve, govulncheck)
- Multi-stage Docker builds for development and production

## Working with Go Workspaces

- Each service is an independent Go module
- Shared code is centralized in the `/shared` module
- Use `go work sync` to sync workspace dependencies
- Local development benefits from automatic module resolution
- Version dependencies independently per service