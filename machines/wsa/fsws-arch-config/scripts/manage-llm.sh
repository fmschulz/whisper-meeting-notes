#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                          LLM Stack Management Script                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_DIR="$SCRIPT_DIR/../docker"
DOCKER_CLI="docker"

detect_container_cli() {
    if command -v docker >/dev/null 2>&1; then
        DOCKER_CLI="docker"
    elif command -v podman >/dev/null 2>&1; then
        DOCKER_CLI="podman"
    else
        print_error "Neither docker nor podman found. Please install one."
        exit 1
    fi
}

# Create necessary directories
mkdir -p "$DOCKER_DIR"/{models,notebooks,characters,extensions,presets,images}

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════╗
║                         NEXUS LLM Stack Manager                           ║
╚══════════════════════════════════════════════════════════════════════════╝

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  start [service]    Start LLM services (or specific service)
  stop [service]     Stop LLM services (or specific service)
  restart [service]  Restart LLM services
  status            Show status of all services
  logs [service]    Show logs (follow mode)
  pull-model        Pull a model for Ollama
  list-models       List available models
  shell [service]   Enter container shell
  clean            Clean up containers and volumes
  help             Show this help message

Services:
  ollama           - Local LLM inference
  vllm             - High-performance inference
  localai          - OpenAI compatible API
  webui            - Text Generation WebUI
  open-webui       - Ollama Web Interface
  jupyter          - Jupyter Lab for ML

Examples:
  $(basename "$0") start              # Start all services
  $(basename "$0") start ollama       # Start only Ollama
  $(basename "$0") pull-model llama2  # Pull llama2 model
  $(basename "$0") logs vllm          # View vLLM logs
  $(basename "$0") shell jupyter      # Enter Jupyter container

Web Interfaces:
  Ollama API:       http://localhost:11434
  vLLM API:         http://localhost:8000
  LocalAI API:      http://localhost:8080
  Text Gen WebUI:   http://localhost:7860
  Open WebUI:       http://localhost:3000
  Jupyter Lab:      http://localhost:8888 (token: nexus2024)

EOF
}

check_docker() {
    detect_container_cli
    if [ "$DOCKER_CLI" = "docker" ]; then
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running!"
            print_info "Try: sudo systemctl start docker"
            exit 1
        fi
    fi
}

check_gpu() {
    if nvidia-smi &> /dev/null; then
        print_info "NVIDIA GPU detected"
        return 0
    elif rocm-smi &> /dev/null; then
        print_info "AMD GPU detected"
        return 0
    else
        print_warning "No GPU detected - using CPU mode"
        return 1
    fi
}

start_services() {
    local service="$1"
    check_docker
    check_gpu

    cd "$DOCKER_DIR"

    if [ -z "${service:-}" ]; then
        print_info "Starting all LLM services..."
        if ! $DOCKER_CLI compose -f llm-stack.yml up -d; then
            print_error "Failed to start services. Try: $DOCKER_CLI compose -f llm-stack.yml config"
            exit 1
        fi
    else
        print_info "Starting $service..."
        if ! $DOCKER_CLI compose -f llm-stack.yml up -d "$service"; then
            print_error "Failed to start $service. Try: $DOCKER_CLI compose -f llm-stack.yml config"
            exit 1
        fi
    fi

    print_success "Services started!"
    print_info "Run '$(basename "$0") status' to check service status"
}

stop_services() {
    local service="$1"
    check_docker

    cd "$DOCKER_DIR"

    if [ -z "${service:-}" ]; then
        print_info "Stopping all LLM services..."
        $DOCKER_CLI compose -f llm-stack.yml down
    else
        print_info "Stopping $service..."
        $DOCKER_CLI compose -f llm-stack.yml stop "$service"
    fi

    print_success "Services stopped!"
}

restart_services() {
    local service="$1"
    stop_services "$service"
    sleep 2
    start_services "$service"
}

show_status() {
    check_docker

    print_info "LLM Stack Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$DOCKER_DIR"
    $DOCKER_CLI compose -f llm-stack.yml ps

    echo ""
    print_info "GPU Status:"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader
    else
        echo "No NVIDIA GPU detected"
    fi
}

show_logs() {
    local service="$1"
    check_docker

    cd "$DOCKER_DIR"

    if [ -z "${service:-}" ]; then
        $DOCKER_CLI compose -f llm-stack.yml logs -f --tail=100
    else
        $DOCKER_CLI compose -f llm-stack.yml logs -f --tail=100 "$service"
    fi
}

pull_model() {
    local model="$1"

    check_docker

    if [ -z "${model:-}" ]; then
        print_error "Please specify a model name"
        echo "Examples: llama2, mistral, codellama, mixtral"
        exit 1
    fi

    print_info "Pulling model: $model"
    if ! $DOCKER_CLI ps --format '{{.Names}}' | grep -q '^nexus-ollama$'; then
        print_error "Ollama container 'nexus-ollama' is not running."
        print_info "Start it with: $(basename "$0") start ollama"
        exit 1
    fi
    $DOCKER_CLI exec nexus-ollama ollama pull "$model"
    print_success "Model pulled successfully!"
}

list_models() {
    print_info "Available Ollama models:"

    check_docker

    if $DOCKER_CLI ps --format '{{.Names}}' | grep -q '^nexus-ollama$'; then
        $DOCKER_CLI exec nexus-ollama ollama list 2>/dev/null || print_warning "Could not list models"
    else
        print_warning "Ollama container not running. Start it with: $(basename "$0") start ollama"
    fi

    echo ""
    print_info "Popular models to pull:"
    echo "  • llama2         - Meta's Llama 2"
    echo "  • mistral        - Mistral 7B"
    echo "  • mixtral        - Mixtral 8x7B"
    echo "  • codellama      - Code Llama"
    echo "  • deepseek-coder - DeepSeek Coder"
    echo "  • phi            - Microsoft Phi-2"
    echo "  • neural-chat    - Intel Neural Chat"
    echo "  • starling-lm    - Starling 7B"
}

enter_shell() {
    local service="$1"

    check_docker

    if [ -z "${service:-}" ]; then
        print_error "Please specify a service name"
        exit 1
    fi

    local container="nexus-$service"

    if [ "$service" == "open-webui" ]; then
        container="nexus-open-webui"
    elif [ "$service" == "webui" ]; then
        container="nexus-webui"
    fi

    print_info "Entering $container shell..."
    $DOCKER_CLI exec -it "$container" /bin/bash || $DOCKER_CLI exec -it "$container" /bin/sh
}

clean_stack() {
    print_warning "This will remove all LLM containers and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        check_docker
        cd "$DOCKER_DIR"
        $DOCKER_CLI compose -f llm-stack.yml down -v
        print_success "LLM stack cleaned!"
    else
        print_info "Cleanup cancelled"
    fi
}

probe_http() {
    local name="$1" url="$2"
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS -m 2 "$url" >/dev/null; then
            print_success "$name: HTTP OK ($url)"
        else
            print_warning "$name: HTTP probe failed ($url)"
        fi
    else
        print_warning "curl not found; skipping HTTP probe for $name"
    fi
}

health_check() {
    local target="$1"
    check_docker
    cd "$DOCKER_DIR"

    local services=("ollama" "vllm" "localai" "webui" "open-webui" "jupyter")
    for svc in "${services[@]}"; do
        if [ -n "$target" ] && [ "$svc" != "$target" ]; then
            continue
        fi
        local container="nexus-$svc"
        [ "$svc" = "open-webui" ] && container="nexus-open-webui"
        [ "$svc" = "webui" ] && container="nexus-webui"

        local status
        status=$($DOCKER_CLI ps --filter "name=^/${container}$" --format '{{.Status}}')
        if [ -z "$status" ]; then
            print_warning "$svc: container not running"
            continue
        fi
        print_info "$svc: $status"

        case "$svc" in
            ollama) probe_http "ollama" "http://localhost:11434/api/tags" ;;
            vllm) probe_http "vllm" "http://localhost:8000" ;;
            localai) probe_http "localai" "http://localhost:8080" ;;
            open-webui) probe_http "open-webui" "http://localhost:3000" ;;
            jupyter) probe_http "jupyter" "http://localhost:8888" ;;
        esac
    done
}

# Main command handler
case "$1" in
    start)
        start_services "$2"
        ;;
    stop)
        stop_services "$2"
        ;;
    restart)
        restart_services "$2"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    pull-model)
        pull_model "$2"
        ;;
    list-models)
        list_models
        ;;
    shell)
        enter_shell "$2"
        ;;
    clean)
        clean_stack
        ;;
    health)
        health_check "$2"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
