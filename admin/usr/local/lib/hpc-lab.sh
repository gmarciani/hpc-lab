# Shared helpers for admin scripts. Source it; do not execute it.
set -euo pipefail
# Both come from admin/.env.local (compose exec) or /etc/environment (ssh).
: "${LAB_DIR:?}" "${KUBECONFIG:?}"

# load_env FILE...: source env files from the mounted lab folders (KEY=value lines).
function load_env() { local f; for f in "$@"; do [ -f "$f" ] || fail "missing $f"; set -a; . "$f"; set +a; done; }

function phase() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
function info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
function error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }
function fail()  { error "$*"; exit 1; }

# wait_pods_gone NAMESPACE LABEL_SELECTOR TIMEOUT_SECONDS
function wait_pods_gone() {
  local ns=$1 selector=$2 timeout=$3 start=$SECONDS
  while [ -n "$(kubectl -n "$ns" get pods -l "$selector" --no-headers 2>/dev/null)" ]; do
    if [ $((SECONDS - start)) -ge "$timeout" ]; then
      kubectl -n "$ns" get pods -l "$selector" || true
      fail "pods matching '$selector' in $ns still present after ${timeout}s"
    fi
    sleep 5
  done
}

# helm_install RELEASE CHART VERSION NAMESPACE [extra helm args...]
function helm_install() {
  local release=$1 chart=$2 version=$3 ns=$4; shift 4
  info "helm upgrade --install $release ($chart $version) in $ns"
  helm upgrade --install "$release" "$chart" --version "$version" --namespace "$ns" --create-namespace "$@" \
    || { kubectl -n "$ns" get pods 2>/dev/null || true; fail "helm release $release in namespace $ns failed"; }
}
