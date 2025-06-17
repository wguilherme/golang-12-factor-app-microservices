#!/bin/bash

# =============================================================================
# Docker Build Optimization Script for Go Monorepo
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT COMPOSE_DOCKER_CLI_BUILD

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    log_info "Checking Docker status..."
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
}

# Clean up old builds and caches
cleanup_docker() {
    log_info "Cleaning up Docker resources..."
    
    # Remove unused containers, networks, images
    docker system prune -f --volumes >/dev/null 2>&1 || true
    
    # Remove build cache (keep recent ones)
    docker buildx prune -f --keep-storage 1GB >/dev/null 2>&1 || true
    
    log_success "Docker cleanup completed"
}

# Create multi-platform builder
setup_builder() {
    log_info "Setting up multi-platform builder..."
    
    # Create builder if it doesn't exist
    if ! docker buildx ls | grep -q "monorepo-builder"; then
        docker buildx create --name monorepo-builder --driver docker-container --bootstrap >/dev/null 2>&1
        log_success "Multi-platform builder created"
    else
        log_info "Multi-platform builder already exists"
    fi
    
    # Use the builder
    docker buildx use monorepo-builder >/dev/null 2>&1
}

# Pre-build base images
prebuild_base() {
    log_info "Pre-building base images..."
    
    # Pull Go base image
    docker pull golang:1.23-alpine3.20 >/dev/null 2>&1 &
    
    # Pull distroless image
    docker pull gcr.io/distroless/static:nonroot >/dev/null 2>&1 &
    
    wait
    log_success "Base images downloaded"
}

# Build with optimizations
build_optimized() {
    local service=${1:-"all"}
    
    log_info "Building services with optimizations..."
    
    # Export environment variables for Docker Compose
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    if [[ "$service" == "all" ]]; then
        # Build all services in parallel
        docker compose -f devops/docker/docker-compose.monorepo.yaml build \
            --parallel \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            --progress=plain
    else
        # Build specific service
        docker compose -f devops/docker/docker-compose.monorepo.yaml build \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            --progress=plain \
            "worker-${service//_/-}"
    fi
    
    log_success "Build completed for: $service"
}

# Show build statistics
show_stats() {
    log_info "Docker images size statistics:"
    echo
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | \
        grep -E "(microservice|golang|distroless)" | head -10
    echo
    
    log_info "Build cache usage:"
    docker system df
}

# Main function
main() {
    local command=${1:-"build"}
    local service=${2:-"all"}
    
    case $command in
        "setup")
            check_docker
            setup_builder
            prebuild_base
            log_success "Docker optimization setup completed"
            ;;
        "build")
            check_docker
            build_optimized "$service"
            show_stats
            ;;
        "clean")
            check_docker
            cleanup_docker
            log_success "Docker cleanup completed"
            ;;
        "full")
            check_docker
            cleanup_docker
            setup_builder
            prebuild_base
            build_optimized "$service"
            show_stats
            log_success "Full optimization cycle completed"
            ;;
        *)
            echo "Usage: $0 {setup|build|clean|full} [service]"
            echo "  setup: Setup optimization tools"
            echo "  build: Build services with optimizations"
            echo "  clean: Clean up Docker resources"
            echo "  full:  Complete optimization cycle"
            echo ""
            echo "Examples:"
            echo "  $0 setup"
            echo "  $0 build worker_flow"
            echo "  $0 full all"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"