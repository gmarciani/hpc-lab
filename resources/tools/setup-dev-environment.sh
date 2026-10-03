#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="$(realpath "$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/../..")"

source "${PROJECT_PATH}/resources/tools/common.sh"

# Commands that need root on Linux; empty when already root (containers, CI).
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

case "$(uname -s)" in
  Darwin)
    info "Installing tools with Homebrew"
    brew install docker docker-compose # Docker environment
    brew install jq # Required by some of our scripts
    brew install pyenv # Python Virtual Environments
    brew install pre-commit
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      info "Installing tools with apt"
      ${SUDO} apt-get update
      ${SUDO} apt-get install -y docker.io docker-compose-v2 jq make pre-commit curl git
    elif command -v dnf >/dev/null 2>&1; then
      info "Installing tools with dnf"
      ${SUDO} dnf install -y moby-engine docker-compose jq make pre-commit curl git
    else
      fail "Unsupported Linux distribution: neither apt-get nor dnf found"
    fi
    # The lab runs the Docker daemon; let the current user talk to it.
    ${SUDO} systemctl enable --now docker 2>/dev/null || warn "Could not enable the docker service; start it manually"
    [ "$(id -u)" -eq 0 ] || ${SUDO} usermod -aG docker "${USER}"
    # No distribution packages pyenv; its installer is not idempotent, hence the guard.
    if [ ! -d "${HOME}/.pyenv" ]; then
      info "Installing pyenv"
      curl -fsSL https://pyenv.run | bash
    fi
    ;;
  *)
    fail "Unsupported operating system: $(uname -s)"
    ;;
esac

info "Installing pre-commit hooks"
pre-commit install

success "Done. On macOS allocate at least 12 GiB of memory to Docker Desktop; on Linux log out and in again for the docker group. Then run: make start"
