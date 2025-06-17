# build args
ARG APP=worker_flow
ARG GOLANG_VERSION=1.23
ARG ALPINE_VERSION=3.20
ARG PORT=8080

# security args
ARG USER_ID=65532
ARG GROUP_ID=65532

# build dependencies
FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /app

# install build dependencies
RUN apk --no-cache add ca-certificates git make

# copy workspace and dependency files for better layer caching
COPY go.work go.work.sum* ./
COPY shared/go.mod shared/go.sum ./shared/
COPY services/*/go.mod services/*/go.sum ./services/*/
COPY tools/go.mod tools/go.sum ./tools/
RUN go work sync

# build the application
FROM deps AS builder
ARG APP
WORKDIR /app

# Copy source code
COPY . .

# Build the specific application binary based on APP argument
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go work sync && \
    cd services/${APP} && \
    go build -ldflags="-s -w" \
    -mod=readonly -o /app/build/${APP} .

# Third stage: Security scanning
FROM builder AS security
RUN go install github.com/securego/gosec/v2/cmd/gosec@latest
RUN gosec ./...

# Fourth stage: Run tests
FROM builder AS test
RUN CGO_ENABLED=0 GOOS=linux go test -v ./... -coverprofile ./cover.out

# Fifth stage: Debug image with delve for development
FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS debug
ARG APP
WORKDIR /app

# Install tools needed for development
RUN apk --no-cache add ca-certificates git make

# Copy entire codebase
COPY . .

# Install and configure delve
RUN go install github.com/go-delve/delve/cmd/dlv@latest
EXPOSE 2345

# Use a volume for hot reloading in development
VOLUME ["/app"]

# Define startup command for debug mode - shell form to allow variable expansion
CMD cd services/$APP && go run .

# Final stage: Production-ready minimal image
FROM gcr.io/distroless/static:nonroot AS prod
ARG APP
ARG PORT
WORKDIR /app

# Copy only the compiled binary from the builder stage
COPY --from=builder /app/build/${APP} /app/application

# Expose the application port
EXPOSE ${PORT}

# Use non-root user for security
USER ${USER_ID}:${GROUP_ID}

# Set default command to run the application
CMD ["/app/application"]
