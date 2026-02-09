#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="$(realpath "$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/..")"

source "${PROJECT_PATH}/tools/common.sh"

info "Installing tools"
brew install docker docker-compose # Docker environment
brew install mysql # MySQL client
brew install jq # Required by some of our scripts
brew install pyenv # Python Virtual Environments

info "Installing pre-commit"
brew install pre-commit
pre-commit install
