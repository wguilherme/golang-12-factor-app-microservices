# Go Workspace Dockerfile with Air + Delve for remote debugging
FROM golang:1.24-alpine3.20

WORKDIR /workspace

ENV GO111MODULE="on"
ENV GOOS="linux"
ENV CGO_ENABLED=0

# Install system dependencies
RUN apk update && apk add --no-cache ca-certificates git && update-ca-certificates

# Install development tools for hot reload and debugging
RUN go install github.com/air-verse/air@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest

# Expose service and debug ports
EXPOSE 8080 8081 2345 2346

# Air will be started via docker-compose with specific config
ENTRYPOINT ["air"]