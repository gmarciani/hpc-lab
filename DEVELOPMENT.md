# Development

## Prerequisites

- [Docker](https://www.docker.com) with [Docker Compose](https://docs.docker.com/compose/)
- [GNU Make](https://www.gnu.org/software/make/)
- [Homebrew](https://brew.sh) on macOS

`make setup` installs them on macOS and Linux and installs the pre-commit hooks.

## Quick start

```shell
make start
```

It builds the images, starts the Kubernetes cluster and deploys the Slurm cluster on it.
For host `kubectl`, run `eval "$(make kubeconfig)"`.

## Project structure

```
docker-compose.yaml     services: k8s-control-plane, k8s-worker-1, k8s-worker-2, admin
Makefile                lifecycle targets
k8s/
  .env.secrets.local    kubeadm token (generated, gitignored)
  control-plane/        node image: Dockerfile, kubeadm.conf, systemd unit, kubeadm init bootstrap
  worker/               node image: Dockerfile, systemd unit, kubeadm join bootstrap
admin/                  sshd, kubectl, helm and the lab scripts
  .env.local            lab directory and kubeconfig path inside the container
  etc/                  sshd configuration
  usr/local/bin/        scripts run by the Makefile and from `make ssh-admin`
  usr/local/lib/        shared bash helpers
  ssh/                  SSH keypair for the admin container (generated, gitignored)
slurm/
  .env.local            cert-manager and Slinky chart versions
  values/slurm.yaml     Helm values for the Slurm cluster: nodes, partitions, login
  slurm.conf            extra slurm.conf settings appended to the generated configuration
resources/              brand assets, host-side scripts
```

## Common commands

| Operation | Command |
|---|---|
| Build images | `make build` (or `make build service=admin`); `make start` runs it first |
| Start / stop / destroy everything | `make start` / `make stop` / `make clean` |
| Start / stop the Kubernetes layer | `make start-k8s` / `make stop-k8s` |
| Start / stop the Slurm layer | `make start-slurm` / `make stop-slurm` |
| Health check of Kubernetes / hello world Slurm job | `make test-k8s` / `make test-slurm` |
| Containers and URLs / both clusters | `make show` / `make describe` (also the last step of `make start`) |
| Container logs | `make get-logs service=k8s-control-plane` |
| Shell in a compose service | `make login service=k8s-worker-1` |
| SSH into admin | `make ssh-admin` |
| Shell on the Slurm login / head / a compute node | `make ssh-slurm-login` / `make ssh-slurm-head` / `make ssh-slurm-compute node=cpu-1` |
| Host kubectl config | `make kubeconfig` |

Inside the admin container: `kubectl`, `helm`, `slurm-deploy`, `slurm-destroy`, `k8s-test`, `slurm-test`.
`slurm-exec [head|login|compute NODE] <command>` runs a command on a Slurm node, the head node by default.
`slurm-shell head|login|compute NODE` opens a shell there.

Each service folder holds a committed `.env.local` and, where needed, a gitignored `.env.secrets.local` that `make start-k8s` generates.
To change the Slurm cluster, edit `slurm/values/slurm.yaml` (nodes, partitions, login) or `slurm/slurm.conf` (scheduler and other `slurm.conf` settings) and run `make start-slurm`.
To change chart versions, edit `slurm/.env.local` and run `make start-slurm`.
Host ports are in `docker-compose.yaml`.
The control-plane hostname `k8s-control-plane` and API port `6443` appear there, in `k8s/control-plane/etc/kubeadm.conf` and in the worker bootstrap.
The Kubernetes version is the `kindest/node` tag in both `k8s/*/Dockerfile` and `kubernetesVersion` in `kubeadm.conf`, and must stay within one minor of `KUBECTL_VERSION` in `admin/Dockerfile`.
Changing them needs `make redeploy`.
Pod and service subnets are in `kubeadm.conf`.

## Node image

Kubernetes publishes no node image.
https://kubernetes.io/releases/download/ offers the control-plane images on `registry.k8s.io`, which kubeadm pulls, and the kubeadm, kubelet and kubectl binaries and packages.
`kindest/node`, built by the Kubernetes SIGs kind project, bundles those binaries with systemd, containerd and the fixes needed to run kubelet inside a container (cgroup root, machine-id, mount propagation, DNS forwarding to Docker's resolver).
The trade-off: the image is maintained by kind rather than by the Kubernetes release team, and building it from official packages would mean rewriting those container fixes in this repository.

## Testing

There is no automated test suite by design.
`make test-k8s` checks the API server readiness and that every node is Ready.
`make test-slurm` submits a hello world batch job, prints its final state and reads its output from `/shared`.

## Release

Update `VERSION` and `CHANGELOG.md`, then:

```shell
VERSION="$(cat VERSION)"
gh release create v${VERSION} --title v${VERSION} --target main --notes-file CHANGELOG.md --latest --draft
gh release edit v${VERSION} --draft=false
```
