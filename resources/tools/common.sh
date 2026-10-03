#!/usr/bin/env bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly GREY='\033[0;90m'
readonly NC='\033[0m' # No Color

function info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function success() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function debug() {
    echo -e "${GREY}[WARNING]${NC} $1"
}

function fail() {
    error "$1"
    exit 1
}
