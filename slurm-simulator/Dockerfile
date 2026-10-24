# The slurm-simulator image holds Cinc Client, its configuration and the
# entrypoint; the entrypoint converges the slurm-simulator cookbook (packages,
# the simulator build, MariaDB, the simulated cluster) at container start, then
# runs MariaDB, the accounting database of the simulated cluster.
# Ubuntu 22.04 is the platform the simulator is developed and tested on upstream
# (its image is built on jupyter/datascience-notebook, Ubuntu 22.04).
FROM ubuntu:22.04
# Cinc Client release: https://downloads.cinc.sh/files/stable/cinc/
ARG CINC_VERSION=19.3.14
# Lab folder inside the container, the same value as the cookbook's `home` attribute.
ARG HPC_LAB_HOME=/opt/hpc-lab
ENV HPC_LAB_HOME=${HPC_LAB_HOME}

# Dependencies of the Cinc installer: the base image ships neither curl nor the
# CA certificates it needs to download over HTTPS.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Cinc Client, the community build of Chef Infra Client.
RUN curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -v "${CINC_VERSION}"

# Cinc configuration; the cookbook is mounted by docker-compose.yaml under
# ${HPC_LAB_HOME}/chef/cookbooks at runtime.
COPY client.rb ${HPC_LAB_HOME}/chef/client.rb
COPY slurm-simulator-entrypoint /usr/local/bin/slurm-simulator-entrypoint

ENTRYPOINT ["/usr/local/bin/slurm-simulator-entrypoint"]
