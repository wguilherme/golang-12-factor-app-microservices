SHELL := /bin/sh
.DEFAULT_GOAL := run

env?=.env
logging_level?=info
app?=worker_flow # worker_flow or worker_post
appsForSecurity?=worker_flow,worker_post
target?=debug # debug or prod

include $(env)

.PHONY: test
test:
	@CGO_ENABLED=0
	@GOOS=linux
	@go test -v ./... -coverprofile ./cover.out
	@go tool cover -html=cover.out

.PHONY: run
run:
	@GOEXPERIMENT=noregabi go run ./cmd/$(app)/main.go -logging_level=$(logging_level)

.PHONY: debug
debug:
	@$(shell which go) build -o ./build/$(app) ./cmd/$(app)/main.go
	@$(shell go env GOPATH)/bin/dlv \
		--listen=:2345 \
		--api-version=2 \
		--headless=true \
		--log=true \
		--accept-multiclient \
			exec ./build/$(app) -logging_level=$(logging_level)

.PHONY: up
up: down
	TARGET=$(target) docker compose --env-file $(env) --file devops/docker/docker-compose.yaml up \
			--build \
			--detach

.PHONY: down
down:
	@docker compose --env-file $(env) --file devops/docker/docker-compose.yaml down \
			--volumes

.PHONY: logs
logs:
	@docker compose --env-file $(env) --file devops/docker/docker-compose.yaml logs $(app) \
			--follow

.PHONY: logs-all
logs-all:
	@docker compose --env-file $(env) --file devops/docker/docker-compose.yaml logs \
			--follow

.PHONY: up-dev
up-dev:
	@$(MAKE) up target=debug app=$(app)

.PHONY: up-prod
up-prod:
	@$(MAKE) up target=prod app=$(app)




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
		gosec -fmt=json -out=reports/gosec/gosec-$$app-report.json ./cmd/$$app/... ./internal/$$app/... || \
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
		govulncheck -json ./cmd/$$app/... ./internal/$$app/... > reports/govulncheck/govulncheck-$$app-report.json || \
		(echo "\033[1;31mVulnerabilities were detected in $$app!\033[0m"); \
	done