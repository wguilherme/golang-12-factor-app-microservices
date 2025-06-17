# Simple Go Workspace Dockerfile
FROM golang:1.24-alpine3.20

WORKDIR /workspace

# Install basic tools
RUN apk --no-cache add ca-certificates git

# Install Air for hot reload
RUN go install github.com/air-verse/air@latest

# Expose ports
EXPOSE 8080 8081 2345 2346

# Air will be started via docker-compose
CMD ["air"]