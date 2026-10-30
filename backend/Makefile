# Orbit backend. Run `make help` for targets. Works without shell setup: the
# Go, sqlc and local tool paths are prepended to PATH here. Override them if
# your tools live elsewhere, e.g. `make test GO_ROOT=/usr/local/go`.
SHELL := /bin/bash
GO_ROOT ?= $(HOME)/.local/go
GO_BIN ?= $(HOME)/go/bin
TOOLS_BIN ?= $(HOME)/.local/bin
export PATH := $(GO_ROOT)/bin:$(GO_BIN):$(TOOLS_BIN):$(PATH)

COMPOSE := docker compose -f ../dev/docker-compose.yml
TEST_DATABASE_URL ?= postgres://orbit:orbit@localhost:5432/orbit_test?sslmode=disable
# Generated files checked by `make check`.
GENERATED = find internal -name 'api.gen.go' -o -path '*/store/*.go' | sort

.PHONY: help dev-up dev-down dev-reset migrate migrate-status migrate-down seed gen build run-api run-worker \
	ping token test test-unit lint check tidy image specs

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

.env:
	cp .env.example .env

dev-up: .env ## Start Postgres+PostGIS and Redis, wait until healthy
	$(COMPOSE) up -d --wait

dev-down: ## Stop dev containers (data volume kept)
	$(COMPOSE) down

dev-reset: ## Stop dev containers and DELETE the data volume
	$(COMPOSE) down -v

migrate: .env ## Apply goose + River migrations to DATABASE_URL
	go run ./cmd/migrate up

migrate-status: .env ## Show migration state
	go run ./cmd/migrate status

migrate-down: .env ## Roll back the latest goose migration
	go run ./cmd/migrate down

seed: .env ## Load dev sample data (idempotent; refuses ORBIT_ENV=prod)
	go run ./cmd/seed

gen: ## Regenerate sqlc stores and oapi-codegen servers for every module
	sqlc generate
	go generate ./internal/...

build: ## Build all binaries into bin/
	go build -o bin/ ./cmd/...

run-api: .env ## Run the API (HTTP_ADDR, default :8080)
	go run ./cmd/api

run-worker: .env ## Run the River worker
	go run ./cmd/worker

ping: .env ## Run the worker once with a system.ping smoke event (Ctrl-C to stop)
	go run ./cmd/worker -ping

KIND ?= ho
ROLE ?= admin
token: .env ## Mint a dev JWT: make token KIND=ho ROLE=ops (KIND=fa|farmer|web)
	@go run ./cmd/devtoken -kind $(KIND) -role $(ROLE)

test: ## Unit + integration tests (integration uses TEST_DATABASE_URL; skipped if DB unreachable)
	TEST_DATABASE_URL="$(TEST_DATABASE_URL)" go test -count=1 ./...

test-unit: ## Unit tests only
	TEST_DATABASE_URL= go test ./...

lint: ## gofmt + go vet (+ golangci-lint if installed)
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi
	go vet ./...
	@if command -v golangci-lint >/dev/null; then golangci-lint run; else echo "golangci-lint not installed; skipped"; fi

check: ## gen must be up to date, then lint and test
	@before=$$(mktemp) && after=$$(mktemp) && trap 'rm -f "$$before" "$$after"' EXIT && \
	$(GENERATED) | xargs sha256sum > "$$before" && \
	$(MAKE) --no-print-directory gen && \
	$(GENERATED) | xargs sha256sum > "$$after" && \
	if ! diff -u "$$before" "$$after"; then \
		echo "generated code was stale; 'make gen' changed the files above. Commit the regenerated files."; exit 1; fi
	@echo "generated code up to date"
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory test

tidy: ## go mod tidy
	go mod tidy

IMAGE ?= orbit-backend
IMAGE_TAG ?= dev
image: ## Build the container image (api, worker, migrate, seed): make image IMAGE_TAG=<git sha>
	docker build -t $(IMAGE):$(IMAGE_TAG) .

specs: ## Regenerate contracts/ENDPOINTS.md and the bundled client specs in contracts/build/
	python3 ../tools/list-endpoints.py
	python3 ../tools/bundle-specs.py
