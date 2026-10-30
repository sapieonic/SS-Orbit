# syntax=docker/dockerfile:1
# Orbit backend image: one image, four binaries. The command picks the process:
#
#   docker run IMAGE api        # HTTP API on HTTP_ADDR (:8080)
#   docker run IMAGE worker     # River worker; /healthz, /readyz on WORKER_HEALTH_ADDR (:8081)
#   docker run IMAGE migrate up # goose + River migrations (needs only DATABASE_URL)
#   docker run IMAGE seed       # dev sample data (refuses ORBIT_ENV=prod)
#
# Build from backend/: `make image` (or docker build -t orbit-backend .).
# Configuration is environment only (see .env.example); no .env is copied in.
# ORBIT_ENV defaults to prod (fail closed); pass ORBIT_ENV=dev to run it against
# the docker-compose database with the dev adapters.

ARG GO_VERSION=1.27

FROM golang:${GO_VERSION} AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOOS=linux GOFLAGS=-trimpath
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    mkdir -p /out && \
    go build -ldflags="-s -w" -o /out/ ./cmd/api ./cmd/worker ./cmd/migrate ./cmd/seed

# Static binaries on distroless: CA certificates and tzdata, no shell, uid 65532.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/ /usr/local/bin/
WORKDIR /home/nonroot
USER nonroot:nonroot
ENV ORBIT_ENV=prod LOG_FORMAT=json HTTP_ADDR=:8080 WORKER_HEALTH_ADDR=:8081
EXPOSE 8080 8081
CMD ["api"]
