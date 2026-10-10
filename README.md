# HPC Lab

<div align="center">
<img src="https://raw.githubusercontent.com/gmarciani/hpc-lab/refs/heads/main/resources/brand/banner.png" alt="hpc-lab-banner" width="500">

[![License](https://img.shields.io/github/license/gmarciani/hpc-lab.svg)](https://github.com/gmarciani/hpc-lab/blob/main/LICENSE)

</div>

## Description

A personal High Performance Computing lab for experimenting with cluster administration and HPC workloads on a [Slurm](https://slurm.schedmd.com) on [Kubernetes](https://kubernetes.io) environment.
On a single workstation it runs a Slurm cluster with a login node and a REST API on top of an upstream Kubernetes cluster.
Everything is a docker-compose project driven by a Makefile.

```
docker-compose project `hpc-lab`
├── admin               sshd + kubectl + helm + lab scripts (ubi9)
├── k8s-control-plane   upstream Kubernetes control plane (kindest/node, kubeadm init on first boot)
├── k8s-worker-1        Kubernetes worker (kindest/node, kubeadm join on first boot)
├── k8s-worker-2        Kubernetes worker
├── k8s-worker-3        Kubernetes worker
└── k8s-worker-4        Kubernetes worker, one per Slurm compute node

Kubernetes
├── cert-manager            namespace cert-manager
├── slurm-operator          namespace slinky     (SchedMD Slinky)
└── slurm                   namespace slurm      (slurmctld, slurmrestd,
                                                  partitions main (cmpt-0, cmpt-1) and
                                                  main-gpu (cmpt-gpu-0, cmpt-gpu-1), 1 login node,
                                                  /shared on login and compute nodes)
```

Every container is configured by Chef: [Cinc Client](https://cinc.sh), the community build of Chef Infra Client, converges each component's cookbook (`admin/cookbook`, `k8s/cookbook`, `slurm/cookbook`) in local mode: at image build only the node's systemd unit that runs the first converge, everything else at container start.
The admin container is the operator's workstation: it holds the kubeconfig, kubectl, helm and the lab scripts, and is the only service reachable over SSH.
The Kubernetes nodes are privileged containers built on `kindest/node`; on first boot a systemd unit runs `kubeadm init` on the control plane and `kubeadm join` on the workers.
`make start-slurm` converges a recipe there that installs cert-manager, the Slinky operator and the Slurm chart with Helm.

| Component | Local endpoint |
|---|---|
| Kubernetes API | `https://localhost:6443` (`make kubeconfig`) |
| Admin container SSH | `ssh -p 2200 root@localhost` (`make ssh-admin`) |

## Requirements

Docker with Compose v2 and GNU Make, installed by `make setup` on macOS and Linux.
On macOS, Docker Desktop needs at least 12 GiB of memory.

## Quick start

```shell
make setup
make start
```

The first `make start` takes about ten minutes.
It ends with a description of the Kubernetes cluster (containers, nodes, pods) and of the Slurm cluster (`sinfo` showing the partitions main and main-gpu, two idle nodes each).

## Usage

### Access

Only the admin node runs an SSH server; it is the operator's workstation and the entry point to both clusters.
Its root authorized key is the lab keypair `admin/ssh/id_ed25519` (gitignored): `make ssh-key` generates it, keeps an existing one, and `make start` runs it for you.

| Where | Command | How it works |
|---|---|---|
| Admin node | `make ssh-admin` | SSH as root on `localhost:2200` with the lab key (`ssh -i admin/ssh/id_ed25519 -p 2200 root@localhost`) |
| Kubernetes node | `make login service=k8s-control-plane` (or `k8s-worker-1` to `k8s-worker-4`) | a bash shell through `docker compose exec`; the nodes run no SSH server |
| Slurm login node | `make ssh-slurm-login` | a shell through `kubectl exec` from the admin node into the login pod |
| Slurm head node (slurmctld) | `make ssh-slurm-head` | the same, into the controller pod |
| Slurm compute node | `make ssh-slurm-compute node=cmpt-1` | the same, into the slurmd pod of that node |

From the admin node, `slurm-exec [head|login|compute NODE] <command>` runs a single command on a Slurm node and `kubectl`, `helm` manage the Kubernetes cluster.
The Slurm pods run the upstream Slinky images, whose SSH server accepts only root keys, and the Kubernetes nodes have none; an administrator account reachable over SSH on both is a planned feature.

```shell
make ssh-slurm-login   # shell on the Slurm login node
sinfo
srun -N2 hostname

make ssh-admin         # SSH into the admin node
kubectl get pods -A
slurm-exec squeue      # run a command on the Slurm head node
```

```shell
make test-k8s       # health check of the Kubernetes cluster
make test-slurm     # submit a hello world batch job
make lint           # lint the Chef cookbooks and the shell scripts
make test           # lint, then unit-test the Chef cookbooks
make stop-slurm     # remove Slurm, keep Kubernetes running
make start-slurm    # bring it back
make stop-k8s       # freeze the whole lab
make start-k8s      # resume it
make clean          # destroy everything, including volumes
```

## Docs

- [DEVELOPMENT.md](DEVELOPMENT.md): prerequisites, setup, project structure, commands, and operating the Kubernetes and Slurm clusters (scaling nodes, adding partitions, submitting jobs).
- [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## Issues

Please report any issues or feature requests on the [GitHub Issues](https://github.com/gmarciani/hpc-lab/issues) page.

## License

This project is licensed under the MIT License.
See the [LICENSE](https://github.com/gmarciani/hpc-lab/blob/main/LICENSE) file for details.
