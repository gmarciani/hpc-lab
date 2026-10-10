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
docker-compose.yaml     services: admin, k8s-control-plane, k8s-worker-1 to k8s-worker-4
Makefile                lifecycle, lint and test targets
admin/
  Dockerfile            ubi9 + Cinc + the entrypoint, which converges the cookbook at container start
  admin-entrypoint      container entrypoint: converge, then sshd
  client.rb             Cinc Client local-mode configuration, copied into the image
  cookbook/             hpc-lab-admin: recipes dependencies (packages, kubectl, helm), ssh, libraries (lab scripts)
  ssh/                  SSH keypair for the admin container (generated, gitignored)
k8s/
  Dockerfile            kindest/node + Cinc + recipe hpc-lab-k8s::image
  client.rb             Cinc Client local-mode configuration, copied into the image
  cookbook/             hpc-lab-k8s: kubeadm.conf, first-boot unit, kubeadm init / join
  .env.secrets.local    kubeadm token (generated, gitignored)
slurm/
  cookbook/             hpc-lab-slurm: deploy / destroy of cert-manager, the Slinky operator and the Slurm chart
resources/              brand assets, host-side scripts
```

Inside a container the lab lives under `/opt/hpc-lab` (the cookbooks' `home` attribute, declared once per Dockerfile as `HPC_LAB_HOME`): `chef/client.rb` and the cookbooks it runs, mounted read-only under `chef/cookbooks/<name>` at image build and at runtime, and on admin the `ssh/` keypair.
A cookbook's `files/` and `templates/` mirror the target filesystem; each `files/` directory is copied whole (`remote_directory`). The `home` attribute reaches the admin scripts as `HPC_LAB_HOME`, exported by the `hpc-lab.sh` library template they source, and the node unit through its template.
The k8s `image` recipe holds only what must exist before the first converge can run, the systemd unit that runs it; the admin image needs only the entrypoint, copied by its Dockerfile. Everything else is in the `default` recipes, applied at container start.
`make start-k8s` therefore waits for the admin container to become healthy (sshd listening, which the entrypoint starts after the converge) before running the lab scripts in it.

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
| First-boot (kubeadm) log of a node | `docker compose exec k8s-control-plane journalctl -u k8s-bootstrap` (same for a worker service) |
| Lint the cookbooks / the shell scripts | `make lint-chef` / `make lint-shell` (both: `make lint`; one cookbook: `make lint-chef cookbook=slurm`) |
| Unit-test the cookbooks | `make test-chef` (with `make lint`: `make test`; one cookbook: `make test-chef cookbook=slurm`) |
| Shell in a compose service | `make login service=k8s-worker-1` |
| SSH into admin | `make ssh-admin` |
| Shell on the Slurm login / head / a compute node | `make ssh-slurm-login` / `make ssh-slurm-head` / `make ssh-slurm-compute node=cmpt-1` |
| Generate the lab SSH keypair (kept if present) | `make ssh-key` |
| Host kubectl config | `make kubeconfig` |

Inside the admin container: `kubectl`, `helm`, `slurm-deploy`, `slurm-destroy`, `k8s-test`, `slurm-test`.
`slurm-exec [head|login|compute NODE] <command>` runs a command on a Slurm node, the head node by default.
`slurm-shell head|login|compute NODE` opens a shell there.

Configuration is cookbook attributes, one file per component under `*/cookbook/attributes/default.rb`:
the Slurm cluster shape, chart versions and `slurm.conf` settings (`make start-slurm` applies them, no rebuild needed since the cookbook is mounted);
the Kubernetes version, control-plane endpoint and subnets (`make redeploy`), where the version must match the `kindest/node` tag in `k8s/Dockerfile` and stay within one minor of the admin `kubectl_version`.
Host ports are in `docker-compose.yaml`; the Cinc Client version is the `CINC_VERSION` build argument of each Dockerfile.

## Operations

The lab is managed from the host with `make` and from the admin node (`make ssh-admin`), which holds `kubectl`, `helm` and the lab scripts; Slurm users work on the login node (`make ssh-slurm-login`).
[Access](README.md#access) in the README lists how to reach every node.
Unless a block says otherwise, the commands below run on the admin node.

### Kubernetes cluster

Inspect the cluster:

```shell
kubectl get nodes -o wide                                        # nodes, versions and IPs
kubectl describe node k8s-worker-1                               # capacity, conditions, pods
kubectl get pods -A -o wide --field-selector spec.nodeName=k8s-worker-1  # pods on a node
make test-k8s                                                    # API readiness and node status (host)
```

Logs of a node, on the host: `docker compose exec k8s-worker-1 journalctl -u kubelet` for kubelet and `journalctl -u k8s-bootstrap` for its first boot (`kubeadm init` or `join`).

**Add a worker.** Every node is a compose service; a new one joins the cluster on its first boot.

1. In `docker-compose.yaml`, add a service after the last worker:

   ```yaml
   k8s-worker-5:
     <<: *k8s-worker
     hostname: k8s-worker-5
   ```

2. In `admin/cookbook/files/usr/local/bin/k8s-wait`, raise `NODES` to the new total (control plane included), so `make start-k8s` waits for the new node.
3. On the host, run `make start-k8s`: compose builds and starts the new service, which runs `kubeadm join`, and the command returns once every node is Ready.

**Remove a worker** (here `k8s-worker-5`):

1. Move its pods away and remove it from the cluster: `kubectl drain k8s-worker-5 --ignore-daemonsets --delete-emptydir-data`, then `kubectl delete node k8s-worker-5`.
2. On the host, remove the container and its volumes: `docker compose rm --stop --force --volumes k8s-worker-5`, then `docker image rm hpc-lab-k8s-worker-5`.
3. Delete the service from `docker-compose.yaml` and lower `NODES` in `k8s-wait`.

**Maintenance of a node:** `kubectl drain k8s-worker-1 --ignore-daemonsets --delete-emptydir-data` evicts its pods and `kubectl uncordon k8s-worker-1` returns it to service.
The Slinky operator runs at most one slurmd pod per Kubernetes node: while a worker is drained, the Slurm compute node it hosted stays Pending unless another worker has no slurmd pod.

### Slurm cluster

The cluster shape is in `slurm/cookbook/attributes/default.rb`: node sets (groups of identical compute nodes), partitions (queues), node features and extra `slurm.conf` settings.
After editing it, run `make start-slurm` on the host: it upgrades the Slurm release only when the rendered configuration changed, then waits until every compute node is idle.
The operator applies a partition change to the running controller a few seconds after the upgrade.

Inspect the cluster, from the admin node through `slurm-exec` or directly on the login node:

```shell
slurm-exec sinfo                                   # partitions and node states
slurm-exec sinfo -N -o "%n %P %t %f %E"            # per node: partition, state, features, reason
slurm-exec scontrol show node cmpt-0               # one node in detail
slurm-exec scontrol show partition main            # one partition in detail
kubectl -n slurm get nodesets,loginsets,pods -o wide  # the Kubernetes side: node sets, login set, pods
```

**Scale compute nodes.** Change the `replicas` of a node set, e.g. `'cmpt' => { 'replicas' => 3, ... }`, then `make start-slurm`.
Node names follow `<node set>-<ordinal>`, from 0; scaling down removes the highest ordinals.
Each compute node needs its own Kubernetes worker: with more replicas in total than workers, the extra pods stay Pending, so add workers first.
After scaling down, the controller keeps the removed node as `drain*` (reason `slurm-operator: Pod is terminating`); delete the record with `slurm-exec scontrol delete nodename=cmpt-2`.

**Add a partition on existing nodes.** A node may belong to several partitions. Add an entry to `partitions`:

```ruby
'debug' => {
  'enabled' => true,
  'nodesets' => %w(cmpt),
  'configMap' => {
    'MaxTime' => '00:30:00',
  },
},
```

`configMap` takes any [partition parameter](https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION) (`Default`, `MaxTime`, `MaxNodes`, ...).

**Add a partition on new nodes.** Add a node set to `nodesets`, e.g. `'cmpt-hm' => { 'replicas' => 1 }`, and a partition listing it, e.g. `'highmem' => { 'enabled' => true, 'nodesets' => %w(cmpt-hm) }`; add one Kubernetes worker per new node first.
To remove a partition or a node set, delete its entry and run `make start-slurm`; the nodes of a removed node set stay as records in the controller, deleted with `slurm-exec scontrol delete nodename=<node>`.

**Node features** are the `features` list of a node set (`%w(gpu)` on `cmpt-gpu`); jobs select them with `--constraint`.
The controller keeps node records across `make stop-slurm`, so a feature change reaches existing nodes only after their records are deleted (`scontrol delete`) or after `make clean`.

**slurm.conf settings** are the `slurm_conf` attributes, rendered by `slurm/cookbook/templates/slurm.conf.erb`, which spells out each setting: a new setting needs an attribute and a line in the template.

**Drain and resume a node:**

```shell
slurm-exec scontrol update nodename=cmpt-0 state=drain reason="maintenance"
slurm-exec scontrol update nodename=cmpt-0 state=resume
```

**Submit jobs**, on the login node (`make ssh-slurm-login`).
Work in `/shared`, the only directory every login and compute node mounts, so job scripts and output files are visible everywhere:

```shell
cd /shared
cat > hello.sbatch <<'SCRIPT'
#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --output=%x-%j.out
srun hostname
SCRIPT
sbatch hello.sbatch                        # batch job; output in hello-<job id>.out
srun -N2 hostname                          # run a command on 2 nodes of the default partition
srun -p main-gpu -C gpu -N2 hostname       # partition main-gpu, nodes with feature gpu
salloc -N1 -p main                         # interactive allocation; srun inside it, exit to release
squeue                                     # pending and running jobs
scontrol show job <job id>                 # one job in detail, also shortly after it ends
scancel <job id>                           # cancel a job
```

Accounting is not deployed, so `sacct` and `sreport` report that accounting storage is disabled; finished jobs stay visible to `scontrol` for `MinJobAge` seconds.
`make test-slurm` (host) submits a hello world job and reads its output from the login node.

**Logs** of the Slurm daemons:

```shell
kubectl -n slurm logs slurm-controller-0 -c slurmctld
kubectl -n slurm logs slurm-worker-cmpt-0 -c slurmd
kubectl -n slurm logs -l app.kubernetes.io/name=login
```

**Remove and redeploy** the Slurm cluster with `make stop-slurm` and `make start-slurm` (host); the operator, cert-manager and the controller state stay, and `make clean` resets everything.

## Node image

Kubernetes publishes no node image.
https://kubernetes.io/releases/download/ offers the control-plane images on `registry.k8s.io`, which kubeadm pulls, and the kubeadm, kubelet and kubectl binaries and packages.
`kindest/node`, built by the Kubernetes SIGs kind project, bundles those binaries with systemd, containerd and the fixes needed to run kubelet inside a container (cgroup root, machine-id, mount propagation, DNS forwarding to Docker's resolver).
The trade-off: the image is maintained by kind rather than by the Kubernetes release team, and building it from official packages would mean rewriting those container fixes in this repository.

## Testing

`make test` runs Cookstyle (`make lint-chef`), ShellCheck on every shell script (`make lint-shell`) and the ChefSpec unit tests of every cookbook (`make test-chef`). Cookstyle and ChefSpec run in the `cincproject/workstation` image and ShellCheck in `koalaman/shellcheck`, so neither Ruby nor ShellCheck is needed on the host; the 🧪 Test workflow runs the same targets on pull requests. ShellCheck finds the scripts by their shebang among the files tracked by git, and `.shellcheckrc` lists the checks disabled for the whole repo.
Specs live in `*/cookbook/spec/unit/recipes/` and converge the recipes in memory against RHEL 9 (admin, slurm) or Debian 13 (k8s) platform data.
`make test-k8s` and `make test-slurm` are the live checks: API server and node readiness, and a hello world batch job whose output is read from `/shared`.

## Release

Update `VERSION` and `CHANGELOG.md`, then:

```shell
VERSION="$(cat VERSION)"
gh release create v${VERSION} --title v${VERSION} --target main --notes-file CHANGELOG.md --latest --draft
gh release edit v${VERSION} --draft=false
```
