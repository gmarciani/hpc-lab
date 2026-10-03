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
├── k8s-control-plane   upstream Kubernetes control plane (k8s/control-plane/, kubeadm init on kindest/node)
├── k8s-worker-1        Kubernetes worker (k8s/worker/, kubeadm join)
├── k8s-worker-2        Kubernetes worker (k8s/worker/, kubeadm join)
└── admin               sshd + kubectl + helm + lab scripts (admin/)

Kubernetes
├── cert-manager            namespace cert-manager
├── slurm-operator          namespace slinky     (SchedMD Slinky)
└── slurm                   namespace slurm      (slurmctld, slurmrestd,
                                                  2 slurmd nodes, 1 login node,
                                                  /shared on login and compute nodes)
```

The Kubernetes nodes are privileged containers built on `kindest/node`; the control plane runs `kubeadm init` and the workers `kubeadm join` on first boot.
The admin container is the operator's workstation: it holds the kubeconfig, kubectl, helm and the lab scripts, and is the only service reachable over SSH.
The Slurm layer is installed with Helm by scripts that run inside the admin container, with chart versions, Helm values and `slurm.conf` under `slurm/`.

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
It ends with a description of the Kubernetes cluster (containers, nodes, pods) and of the Slurm cluster (`sinfo` showing two idle nodes).

## Usage

```shell
make ssh-slurm-login   # shell on the Slurm login node
sinfo
srun -N2 hostname

make ssh-admin         # SSH into the admin container
kubectl get pods -A
slurm-exec squeue      # run a command on the Slurm head node
```

```shell
make test-k8s       # health check of the Kubernetes cluster
make test-slurm     # submit a hello world batch job
make stop-slurm     # remove Slurm, keep Kubernetes running
make start-slurm    # bring it back
make stop-k8s       # freeze the whole lab
make start-k8s      # resume it
make clean          # destroy everything, including volumes
```

## Docs

- [DEVELOPMENT.md](DEVELOPMENT.md): prerequisites, setup, project structure, commands.
- [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## Issues

Please report any issues or feature requests on the [GitHub Issues](https://github.com/gmarciani/hpc-lab/issues) page.

## License

This project is licensed under the MIT License.
See the [LICENSE](https://github.com/gmarciani/hpc-lab/blob/main/LICENSE) file for details.
