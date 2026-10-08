# kindest/node bundles kubeadm, kubelet, kubectl, systemd and containerd (see
# "Node image" in DEVELOPMENT.md). Chef installs the first-boot unit here (recipe
# hpc-lab-k8s::image); the unit converges the default recipe on first boot.
FROM kindest/node:v1.36.4
# Cinc Client release: https://downloads.cinc.sh/files/stable/cinc/
ARG CINC_VERSION=19.3.14
# Lab folder inside the container, the same value as the cookbook's `home` attribute.
ARG HPC_LAB_HOME=/opt/hpc-lab

# Cinc Client, the community build of Chef Infra Client.
RUN curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -v "${CINC_VERSION}"

COPY client.rb ${HPC_LAB_HOME}/chef/client.rb
# The cookbook is read through a build mount instead of a COPY layer:
# - type=bind exposes a folder of the build context to this RUN only, so the
#   image carries no copy of the cookbook that docker-compose.yaml bind-mounts
#   at runtime anyway (a copy would be dead weight and go stale);
# - source=cookbook is the cookbook's path in the build context, this folder;
# - target=${HPC_LAB_HOME}/chef/cookbooks/hpc-lab-k8s is where client.rb looks
#   for cookbooks (chef_repo_path, cookbooks/<cookbook name>) and the same path
#   compose mounts it at, so build and runtime converges agree.
RUN --mount=type=bind,source=cookbook,target=${HPC_LAB_HOME}/chef/cookbooks/hpc-lab-k8s \
    cinc-client -c ${HPC_LAB_HOME}/chef/client.rb -o 'recipe[hpc-lab-k8s::image]'

ENV KUBECONFIG=/etc/kubernetes/admin.conf
