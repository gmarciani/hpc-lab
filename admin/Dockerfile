# The admin image holds Cinc Client, its configuration and the entrypoint; the
# entrypoint converges the admin cookbook (packages, kubectl, helm, sshd, lab
# scripts, SSH key) at container start, then runs sshd.
FROM registry.access.redhat.com/ubi9/ubi:9.8
# Cinc Client release: https://downloads.cinc.sh/files/stable/cinc/
ARG CINC_VERSION=19.3.14
# Lab folder inside the container, the same value as the cookbooks' `home` attribute.
ARG HPC_LAB_HOME=/opt/hpc-lab
ENV HPC_LAB_HOME=${HPC_LAB_HOME}

# Dependencies of Cinc Client: ubi9 ships no hostname binary, which Cinc needs to
# name the node (Chef::Exceptions::CannotDetermineNodeName otherwise).
RUN dnf install -y hostname && dnf clean all

# Cinc Client, the community build of Chef Infra Client.
RUN curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -v "${CINC_VERSION}"

# Cinc configuration; the cookbooks are mounted by docker-compose.yaml under
# ${HPC_LAB_HOME}/chef/cookbooks at runtime.
COPY client.rb ${HPC_LAB_HOME}/chef/client.rb
COPY admin-entrypoint /usr/local/bin/admin-entrypoint

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/admin-entrypoint"]
