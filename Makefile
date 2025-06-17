SHELL := /bin/sh
.DEFAULT_GOAL := run

env?=.env
logging_level?=info
app?=worker_flow # worker_flow or worker_post
appsForSecurity?=worker_flow,worker_post
target?=debug # debug or prod

include $(env)

# Go Workspace commands
.PHONY: workspace-sync
workspace-sync:
	@go work sync

.PHONY: workspace-use
workspace-use:
	@echo "Current workspace modules:"
	@go list -m

.PHONY: test
test:
	@echo "Running tests for all workspace modules..."
	@go work sync
	@CGO_ENABLED=0 GOOS=linux go test ./... -coverprofile ./cover.out
	@go tool cover -html=cover.out

.PHONY: test-service
test-service:
	@echo "Testing service: $(app)"
	@cd services/$(app) && CGO_ENABLED=0 GOOS=linux go test ./... -v

.PHONY: run
run:
	@echo "Running service: $(app)"
	@cd services/$(app) && GOEXPERIMENT=noregabi go run . -logging_level=$(logging_level)

.PHONY: debug
debug:
	@echo "Building service for debug: $(app)"
	@mkdir -p build
	@cd services/$(app) && go build -o ../../build/$(app) .
	@$(shell go env GOPATH)/bin/dlv \
		--listen=:2345 \
		--api-version=2 \
		--headless=true \
		--log=true \
		--accept-multiclient \
			exec ./build/$(app) -logging_level=$(logging_level)

.PHONY: build
build:
	@echo "Building service: $(app)"
	@mkdir -p build
	@cd services/$(app) && CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o ../../build/$(app) .

.PHONY: build-all
build-all:
	@echo "Building all services..."
	@mkdir -p build
	@APPS=$$(echo $(appsForSecurity) | tr ',' ' '); \
	for app in $$APPS; do \
		echo "Building $$app..."; \
		cd services/$$app && CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o ../../build/$$app . && cd ../..; \
	done

# =============================================================================
# Docker Commands - Monorepo Optimized
# =============================================================================

COMPOSE_FILE := devops/docker/docker-compose.yaml
COMPOSE_CMD := docker compose --env-file $(env) --file $(COMPOSE_FILE)

.PHONY: docker-build
docker-build:
	@echo "Building all services..."
	@$(COMPOSE_CMD) build --parallel

.PHONY: docker-build-debug
docker-build-debug:
	@echo "Building all services for debug..."
	@TARGET=debug $(COMPOSE_CMD) build --parallel

.PHONY: docker-build-service
docker-build-service:
	@echo "Building service: $(app)"
	@$(COMPOSE_CMD) build $(subst _,-,$(app))

.PHONY: up
up: down docker-build
	@echo "🚀 Starting services with Hot Reload..."
	@$(COMPOSE_CMD) up --detach
	@echo ""
	@echo "✅ Services running with hot reload:"
	@echo ""
	@echo "🔥 HOT RELOAD (Air):"
	@echo "   📝 Edit files in services/ → automatic rebuild & restart"
	@echo "   📊 Watch logs: make logs app=worker_flow"
	@echo ""
	@echo "🌐 SERVICES:"
	@echo "   • worker_flow: http://localhost:8080/health/live"
	@echo "   • worker_post: http://localhost:8081/health/live"
	@echo ""
	@echo "🐛 For debugging, use: make up-debug"

.PHONY: up-debug
up-debug: down docker-build-debug
	@echo "🚀 Starting services with Hot Reload + Debug support..."
	@TARGET=debug $(COMPOSE_CMD) up --detach
	@echo ""
	@echo "✅ Services running with debug enabled:"
	@echo ""
	@echo "🐛 DEBUG ATTACH (Delve):"
	@echo "   🎯 Set breakpoints in VS Code"
	@echo "   🔗 Use: 'Debug worker_flow (remote)' configuration"
	@echo "   📍 Debug ports: worker_flow:2345, worker_post:2346"
	@echo ""
	@echo "🌐 SERVICES:"
	@echo "   • worker_flow: http://localhost:8080/health/live"
	@echo "   • worker_post: http://localhost:8081/health/live"

.PHONY: up-service
up-service:
	@echo "Starting single service: $(app)"
	@TARGET=$(target) $(COMPOSE_CMD) up $(subst _,-,$(app)) --build --detach

.PHONY: down
down:
	@echo "Stopping all services..."
	@$(COMPOSE_CMD) down --volumes --remove-orphans

.PHONY: down-clean
down-clean:
	@echo "Stopping and cleaning all services..."
	@$(COMPOSE_CMD) down --volumes --remove-orphans --rmi local
	@docker system prune -f

.PHONY: logs
logs:
	@$(COMPOSE_CMD) logs $(subst _,-,$(app)) --follow

.PHONY: logs-all
logs-all:
	@$(COMPOSE_CMD) logs --follow

.PHONY: logs-tail
logs-tail:
	@$(COMPOSE_CMD) logs --follow --tail=100

.PHONY: restart
restart:
	@echo "Restarting service: $(app)"
	@$(COMPOSE_CMD) restart $(subst _,-,$(app))

.PHONY: restart-all
restart-all:
	@echo "Restarting all services..."
	@$(COMPOSE_CMD) restart

.PHONY: ps
ps:
	@$(COMPOSE_CMD) ps

.PHONY: stats
stats:
	@docker stats

.PHONY: shell
shell:
	@echo "Opening shell in service: $(app)"
	@$(COMPOSE_CMD) exec $(subst _,-,$(app)) sh

# =============================================================================
# Docker Health & Monitoring
# =============================================================================

.PHONY: health
health:
	@echo "Checking health of all services..."
	@$(COMPOSE_CMD) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

.PHONY: health-service
health-service:
	@echo "Checking health of service: $(app)"
	@docker inspect --format='{{.State.Health.Status}}' $(subst _,-,$(app)) || echo "No health check configured"

# =============================================================================
# Hot Reload Development Commands
# =============================================================================

.PHONY: dev-test
dev-test:
	@echo "Testing hot reload functionality..."
	@echo "Current time: $(shell date)" 
	@curl -s http://localhost:8080/health/live | jq . || echo "Service not responding"
	@curl -s http://localhost:8081/health/live | jq . || echo "Service not responding"

.PHONY: dev-watch
dev-watch:
	@echo "Watching logs for hot reload changes..."
	@$(COMPOSE_CMD) logs --follow --tail=50




# security
.PHONY: security
security: gosec gitleaks trivy govulncheck
	@echo "\033[1;32mSecurity checks completed for all services\033[0m"

.PHONY: gosec
gosec:
	@echo "\033[1;34mRunning gosec for all microservices...\033[0m"
	@if ! command -v gosec &> /dev/null; then \
		echo "Installing gosec..."; \
		go install github.com/securego/gosec/v2/cmd/gosec@latest; \
	fi
	@mkdir -p reports/gosec
	@APPS=$$(echo $(appsForSecurity) | tr ',' ' '); \
	for app in $$APPS; do \
		echo "\033[1;33mRunning gosec for $$app...\033[0m"; \
		gosec -fmt=json -out=reports/gosec/gosec-$$app-report.json ./services/$$app/... || \
		(echo "\033[1;31mSecurity issues were detected in $$app!\033[0m"); \
	done

.PHONY: hadolint
hadolint:
	@docker run --rm -i -e HADOLINT_FAILURE_THRESHOLD=$(threshold) hadolint/hadolint < devops/docker/Dockerfile

.PHONY: gitleaks
gitleaks:
	@echo "Running gitleaks..."
	@docker run -v ${PWD}:/path -v ${PWD}/reports:/reports zricethezav/gitleaks:latest detect \
		--source="/path" \
		--report-path="/reports/gitleaks-report.json" \
		-v || (echo "Secrets were detected!")

.PHONY: trivy
trivy:
	@echo "\033[1;34mRunning trivy for all microservices...\033[0m"
	@mkdir -p reports/trivy
	@APPS=$$(echo $(appsForSecurity) | tr ',' ' '); \
	for app in $$APPS; do \
		echo "\033[1;33mRunning trivy for $$app...\033[0m"; \
		docker build -t golang-ms-$$app:trivy --build-arg APP=$$app --target builder -f devops/docker/Dockerfile .; \
		docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}/reports/trivy:/reports aquasec/trivy --debug image \
		--list-all-pkgs --exit-code 0 --ignore-unfixed -f json \
		-o /reports/trivy-$$app-report.json golang-ms-$$app:trivy || \
		(echo "\033[1;31mSecurity vulnerabilities were detected in $$app!\033[0m"); \
	done

.PHONY: govulncheck
govulncheck:
	@echo "\033[1;34mRunning govulncheck for all microservices...\033[0m"
	@if ! command -v govulncheck &> /dev/null; then \
		echo "Installing govulncheck..."; \
		go install golang.org/x/vuln/cmd/govulncheck@latest; \
	fi
	@mkdir -p reports/govulncheck
	@APPS=$$(echo $(appsForSecurity) | tr ',' ' '); \
	for app in $$APPS; do \
		echo "\033[1;33mRunning govulncheck for $$app...\033[0m"; \
		cd services/$$app && govulncheck -json ./... > ../../reports/govulncheck/govulncheck-$$app-report.json && cd ../.. || \
		(echo "\033[1;31mVulnerabilities were detected in $$app!\033[0m"); \
	done
