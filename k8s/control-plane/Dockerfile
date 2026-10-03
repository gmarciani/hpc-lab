# kindest/node bundles the official kubeadm, kubelet and kubectl with systemd and
# containerd; see "Node image" in DEVELOPMENT.md for why and for the trade-off.
FROM kindest/node:v1.36.4

# The folder layout mirrors the destination paths in the image.
COPY etc/kubeadm.conf /etc/kubeadm.conf
COPY etc/systemd/system/ /etc/systemd/system/
COPY usr/local/bin/ /usr/local/bin/
RUN systemctl enable k8s-bootstrap.service

ENV KUBECONFIG=/etc/kubernetes/admin.conf
