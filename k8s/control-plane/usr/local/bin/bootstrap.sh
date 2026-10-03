#!/usr/bin/env bash
# First-boot bootstrap of the control plane: kubeadm init, CNI and storage.
set -euo pipefail
# /shared is the cluster-wide scratch directory the Slurm pods mount: writable by
# every job user, with the sticky bit like /tmp.
chmod 1777 /shared

if [ -d /var/lib/etcd/member ]; then
  echo "[bootstrap] etcd data exists but /etc/kubernetes is empty; re-initialising would corrupt the cluster. Run: make clean" >&2
  exit 1
fi

echo "[bootstrap] kubeadm init on $(hostname)"
kubeadm init --config /etc/kubeadm.conf --skip-token-print
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[bootstrap] creating the bootstrap token the workers join with"
kubeadm token create "${K8S_TOKEN}" --ttl 0 >/dev/null

echo "[bootstrap] installing CNI (kindnet) and storage (local-path)"
pod_subnet=$(awk '/podSubnet:/ { gsub(/"/, "", $2); print $2 }' /etc/kubeadm.conf)
# kind's bundled manifest carries a Go template placeholder for the pod subnet.
sed "s|{{ .PodSubnet }}|${pod_subnet}|g" /kind/manifests/default-cni.yaml | kubectl apply -f -
kubectl apply -f /kind/manifests/default-storage.yaml
install -m 644 /etc/kubernetes/admin.conf /output/config
echo "[bootstrap] done"
