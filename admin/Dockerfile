FROM registry.access.redhat.com/ubi9/ubi:9.8
ARG KUBECTL_VERSION=1.36.4
ARG HELM_VERSION=3.22.0
# Set by BuildKit to the build platform's architecture (arm64 on Apple Silicon,
# amd64 on Intel). Declaring it here brings it into scope for the downloads below.
ARG TARGETARCH

RUN dnf install -y openssh-server openssh-clients jq openssl tar gzip \
 && dnf clean all

RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl

RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar -xz -C /tmp \
 && mv "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
 && rm -rf "/tmp/linux-${TARGETARCH}"

# The folder layout mirrors the destination paths in the image.
COPY etc/ssh/sshd_config.d/ /etc/ssh/sshd_config.d/
COPY usr/local/bin/ /usr/local/bin/
COPY usr/local/lib/ /usr/local/lib/
# PAM hands /etc/environment to SSH sessions, so the same env file compose gives
# to `docker compose exec` also reaches `make ssh-admin`.
COPY .env.local /etc/environment
# Host keys generated at build: every container from this image shares them,
# which is fine for a lab bound to localhost.
RUN ssh-keygen -A

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/admin-entrypoint"]
