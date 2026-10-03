#!/usr/bin/env bash
# First-boot bootstrap of a worker: wait for the API server, then kubeadm join.
# No configuration file: the kubelet configuration comes from the cluster and
# kubeadm takes the node name from the hostname.
set -euo pipefail
# /shared is the cluster-wide scratch directory the Slurm pods mount: writable by
# every job user, with the sticky bit like /tmp.
chmod 1777 /shared

echo "[bootstrap] waiting for the API server"
timeout 300 bash -c 'until curl -ksf https://k8s-control-plane:6443/healthz >/dev/null; do sleep 2; done'

echo "[bootstrap] kubeadm join from $(hostname)"
# The CA hash is not verified: the token is a secret shared on a private
# compose network, which is enough for a local lab.
kubeadm join k8s-control-plane:6443 --token "${K8S_TOKEN}" \
  --discovery-token-unsafe-skip-ca-verification --skip-phases preflight
echo "[bootstrap] done"
