SHELL := /bin/sh
.DEFAULT_GOAL := run

env?=.env
logging_level?=info
app?=worker_flow

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
	docker compose --env-file $(env) --file devops/docker/docker-compose.yaml up \
			--build \
			--detach

.PHONY: down
down:
	docker compose --env-file $(env) --file devops/docker/docker-compose.yaml down \
			--volumes

.PHONY: logs
logs:
	docker compose --env-file $(env) --file devops/docker/docker-compose.yaml logs $(app) \
			--follow
