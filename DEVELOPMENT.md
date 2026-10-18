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
docker-compose.yaml     services: admin, kubernetes-control-plane, kubernetes-worker (4 replicas by default); slurm-simulator (profile slurm-simulator, its own network)
Makefile                lifecycle, lint and test targets
admin/
  Dockerfile            ubi9 + Cinc + the entrypoint, which converges the cookbook at container start
  admin-entrypoint      container entrypoint: converge, then sshd
  client.rb             Cinc Client local-mode configuration, copied into the image
  cookbook/             hpc-lab-admin: recipes dependencies (packages, kubectl, helm), ssh, libraries (lab scripts)
  ssh/                  SSH keypair for the admin container (generated, gitignored)
kubernetes/
  Dockerfile            kindest/node + Cinc + recipe hpc-lab-kubernetes::image
  client.rb             Cinc Client local-mode configuration, copied into the image
  cookbook/             hpc-lab-kubernetes: kubeadm.conf, first-boot unit, kubeadm init / join
  .env.secrets.local    kubeadm token (generated, gitignored)
slurm/
  cookbook/             hpc-lab-slurm: deploy / destroy of cert-manager, the Slinky operator and the Slurm chart
slurm-simulator/
  Dockerfile            ubuntu 22.04 + Cinc + the entrypoint, which converges the cookbook at container start
  slurm-simulator-entrypoint  container entrypoint: converge, then MariaDB
  client.rb             Cinc Client local-mode configuration, copied into the image
  cookbook/             hpc-lab-slurm-simulator: recipes dependencies, simulator (build), plugins, database (MariaDB), simulation (cluster, slurm-simulate)
  workloads/            events files to simulate, mounted read-only; lab.events is the sample
  plugins/              custom scheduling policies as Slurm plugins, built into the simulator; priority_sjf.c is the sample
  configs/              one JSON file per experiment, the nodes and policy of a run, mounted read-only; baseline.json, sjf-4.json
  results/              one folder per simulation, mounted (gitignored)
resources/              brand assets, host-side scripts
```

Inside a container the lab lives under `/opt/hpc-lab` (the cookbooks' `home` attribute, declared once per Dockerfile as `HPC_LAB_HOME`): `chef/client.rb` and the cookbooks it runs, mounted read-only under `chef/cookbooks/<name>` at image build and at runtime, and on admin the `ssh/` keypair.
A cookbook's `files/` and `templates/` mirror the target filesystem; each `files/` directory is copied whole (`remote_directory`). The `home` attribute reaches the admin scripts as `HPC_LAB_HOME`, exported by the `hpc-lab.sh` library template they source, and the node unit through its template.
The kubernetes `image` recipe holds only what must exist before the first converge can run, the systemd unit that runs it; the admin and slurm-simulator images need only the entrypoint, copied by their Dockerfile. Everything else is in the `default` recipes, applied at container start.
`make start-kubernetes` therefore waits for the admin container to become healthy (sshd listening, which the entrypoint starts after the converge) before running the lab scripts in it.

## Common commands

| Operation | Command |
|---|---|
| List the targets with their description | `make help` |
| Build images | `make build` (or `make build service=admin`); `make start` runs it first |
| Start / stop the lab (not the Slurm Simulator) / destroy everything (the Slurm Simulator too) | `make start` / `make stop` / `make clean` |
| Start / stop the Kubernetes layer | `make start-kubernetes` / `make stop-kubernetes` |
| Scale the Kubernetes workers | `make start-kubernetes workers=6` (later runs keep the count) |
| Start / stop the Slurm layer | `make start-slurm` / `make stop-slurm` |
| Start / stop / destroy the Slurm Simulator (results stay) | `make start-slurm-simulator` / `make stop-slurm-simulator` / `make clean-slurm-simulator` |
| Rebuild the Slurm Simulator from scratch (a new simulator version) | `make redeploy-slurm-simulator` |
| Simulate a workload and plot it | `make simulate-slurm` (or `make simulate-slurm workload=mine.events config=sjf-4.json run=try1`) |
| Compare simulations in one plot | `make report-slurm runs="lab-baseline lab-sjf-4"` |
| Health check of Kubernetes / hello world Slurm job | `make test-kubernetes` / `make test-slurm` |
| Containers and URLs / both clusters | `make show` / `make describe` (also the last step of `make start`) |
| Container logs | `make get-logs service=kubernetes-control-plane` (a worker: `service=kubernetes-worker-2`) |
| First-boot (kubeadm) log of a node | `docker compose exec kubernetes-control-plane journalctl -u kubernetes-bootstrap` (a worker: `exec --index 2 kubernetes-worker`) |
| Lint the cookbooks / the shell scripts / the Makefile help | `make lint-chef` / `make lint-shell` / `make lint-make` (all: `make lint`; one cookbook: `make lint-chef cookbook=slurm-simulator`) |
| Unit-test the cookbooks | `make test-chef` (with `make lint`: `make test`; one cookbook: `make test-chef cookbook=slurm`) |
| Shell in a compose service | `make login service=admin` (a worker: `service=kubernetes-worker-2`, replica 2) |
| SSH into admin | `make ssh-admin` |
| Shell on the Slurm login / head / a compute node | `make ssh-slurm-login` / `make ssh-slurm-head` / `make ssh-slurm-compute node=cmpt-1` |
| Generate the lab SSH keypair (kept if present) | `make ssh-key` |
| Host kubectl config | `make kubeconfig` |

Inside the admin container: `kubectl`, `helm`, `slurm-deploy`, `slurm-destroy`, `kubernetes-test`, `slurm-test`.
`slurm-exec [head|login|compute NODE] <command>` runs a command on a Slurm node, the head node by default.
`slurm-shell head|login|compute NODE` opens a shell there.

Configuration is cookbook attributes, one file per component under `*/cookbook/attributes/default.rb`:
the Slurm cluster shape, chart versions and `slurm.conf` settings (`make start-slurm` applies them, no rebuild needed since the cookbook is mounted);
the Kubernetes version, control-plane endpoint and subnets (`make redeploy`), where the version must match the `kindest/node` tag in `kubernetes/Dockerfile` and stay within one minor of the admin `kubectl_version`;
the simulated cluster and its scheduling policy, which the configs of `slurm-simulator/configs` override per run (`make simulate-slurm` applies them), and the simulator version (`make redeploy-slurm-simulator`).
Host ports are in `docker-compose.yaml`; the Cinc Client version is the `CINC_VERSION` build argument of each Dockerfile.

## Operations

The lab is managed from the host with `make` and from the admin node (`make ssh-admin`), which holds `kubectl`, `helm` and the lab scripts; Slurm users work on the login node (`make ssh-slurm-login`).
[Access](README.md#access) in the README lists how to reach every node.
Unless a block says otherwise, the commands below run on the admin node.

### Kubernetes cluster

Inspect the cluster:

```shell
kubectl get nodes -o wide                                                       # nodes, versions and IPs
kubectl describe node kubernetes-worker-1                                       # capacity, conditions, pods
kubectl get pods -A -o wide --field-selector spec.nodeName=kubernetes-worker-1  # pods on a node
make test-kubernetes                                                            # API readiness and node status (host)
```

Logs of a node, on the host: `docker compose exec --index 1 kubernetes-worker journalctl -u kubelet` for kubelet and `journalctl -u kubernetes-bootstrap` for its first boot (`kubeadm init` or `join`); `docker compose exec kubernetes-control-plane ...` for the control plane.

**Scale the workers.** The workers are the replicas of the compose service `kubernetes-worker`, 4 by default; replica N joins the cluster as node `kubernetes-worker-N` on its first boot.
On the host, `make start-kubernetes workers=6` scales the service and returns once every node is Ready; later `make start-kubernetes` and `make start` keep the current count, and `make clean` resets it to 4.

- **Scale up:** compose starts the new replicas, which run `kubeadm join`.
- **Scale down:** compose removes the replicas with the highest index, and `make start-kubernetes` deletes their nodes from the cluster. Their pods are rescheduled on the remaining workers; to move them first, drain the nodes that will go, e.g. `kubectl drain kubernetes-worker-6 --ignore-daemonsets --delete-emptydir-data`.

**Maintenance of a node:** `kubectl drain kubernetes-worker-1 --ignore-daemonsets --delete-emptydir-data` evicts its pods and `kubectl uncordon kubernetes-worker-1` returns it to service.
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
Each compute node needs its own Kubernetes worker: with more replicas in total than workers, the extra pods stay Pending, so add workers first (`make start-kubernetes workers=N`).
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

**Add a partition on new nodes.** Add a node set to `nodesets`, e.g. `'cmpt-hm' => { 'replicas' => 1 }`, and a partition listing it, e.g. `'highmem' => { 'enabled' => true, 'nodesets' => %w(cmpt-hm) }`; add one Kubernetes worker per new node first (`make start-kubernetes workers=N`).
To remove a partition or a node set, delete its entry and run `make start-slurm`; the nodes of a removed node set stay as records in the controller, deleted with `slurm-exec scontrol delete nodename=<node>`.

**Node features** are the `features` list of a node set (`%w(gpu)` on `cmpt-gpu`); jobs select them with `--constraint`.

**Memory** is scheduled like cores (`SelectTypeParameters=CR_Core_Memory`). Each node offers the memory limit of its node set (`resources.limits.memory`, in `Mi` or `Gi`) as `RealMemory`, 2048 MiB by default.
A job asks for memory with `--mem` (per node) or `--mem-per-cpu`; without either it gets `DefMemPerCPU` (1024 MiB) per allocated CPU.
A job that uses more than it asked for is killed (`task/cgroup` with `ConstrainRAMSpace` and `ConstrainSwapSpace` in `slurm/cookbook/templates/cgroup.conf.erb`), and a request larger than any node is rejected at submission.

**GPUs** are the `gpus` list of a node set, one entry per GPU with its type: `%w(a100 h100)` on `cmpt-gpu`, so each node of `main-gpu` has an `a100` (index 0) and an `h100` (index 1).
The lab has no GPUs: they are Slurm generic resources (GRES) bound to placeholder devices (`slurm/cookbook/templates/gres.conf.erb`), scheduled and counted like real ones, and a job learns which GPU it got from `CUDA_VISIBLE_DEVICES`.
Jobs ask for them with `--gres=gpu:<count>` (any type), `--gres=gpu:<type>:<count>` or `--gpus=<count>`; with `-w <node>` they target one GPU of one node.

**Node settings** (features, memory, GPUs) apply when a node registers, and the controller keeps node records across pod restarts and `make stop-slurm`.
After changing them, `make start-slurm` restarts the slurmd pods, but existing nodes keep their old settings until their records are re-created: delete the record, then the pod, one node at a time, or run `make clean`:

```shell
slurm-exec scontrol delete nodename=cmpt-0 && kubectl -n slurm delete pod slurm-worker-cmpt-0
```

**slurm.conf settings** are the `slurm_conf` attributes, rendered by `slurm/cookbook/templates/slurm.conf.erb`, which spells out each setting: a new setting needs an attribute and a line in the template.
Other Slurm config files (`cgroup.conf`, `gres.conf`) are templates of their own, mounted next to `slurm.conf`; after an upgrade, `make start-slurm` waits until the controller sees them and runs `scontrol reconfigure`, since the operator restarts the controller only for `slurm.conf` changes.

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
srun --mem=1500M hostname                  # a node with 1500 MiB free; pending while none has
sbatch -c2 --mem-per-cpu=512M job.sbatch   # 2 CPUs and 1 GiB on one node
srun -p main-gpu --gres=gpu:h100:1 env | grep CUDA_VISIBLE_DEVICES  # one h100: CUDA_VISIBLE_DEVICES=1
srun -p main-gpu -w cmpt-gpu-1 --gres=gpu:a100:1 hostname           # the a100 of cmpt-gpu-1
srun -p main-gpu --gpus=2 hostname                                  # both GPUs of a node
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

### Slurm Simulator

The [UB CCR Slurm Simulator](https://github.com/ubccr-slurm-simulator/slurm_sim_tools) (toolkit v3.0, simulator branch `slurm-23-02-sim`) is Slurm's own controller modified to replay a workload on a simulated clock: jobs are submitted, scheduled and completed as in Slurm, but no job runs and no node exists, so a workload of hours takes seconds or minutes.
It runs in the slurm-simulator service, which needs nothing else of the lab and is decoupled from it: its compose profile leaves it out of every compose command that does not name it, it has its own network, and the lab targets (`make build`, `start`, `stop`, `restart`, `start-kubernetes`, ...) leave it alone; only `make clean` (and `make redeploy`, which runs it) destroys it with the rest of the lab.
`make start-slurm-simulator` builds and starts it, with or without the clusters (its first start builds the simulator, a couple of minutes), `make stop-slurm-simulator` stops it, `make clean-slurm-simulator` destroys its container, image and network, keeping `slurm-simulator/results`, and `make redeploy-slurm-simulator` does both, for a new simulator version.
Each simulation starts from scratch: an empty accounting database, the accounts and users of `sacctmgr.script`, then the jobs of the workload.

**Run an experiment**, on the host: a trace of jobs (`workload`), a config with the cluster's nodes and the scheduling policy (`config`), and the name of its results (`run`):

```shell
make simulate-slurm                                    # lab.events with baseline.json, results in slurm-simulator/results/lab-baseline_<time>
make simulate-slurm config=sjf-4.json                  # the same trace under Shortest Job First, results in .../lab-sjf-4_<time>
make simulate-slurm workload=mine.events config=sjf-4.json run=try1   # another trace, results in .../try1_<time>
```

It builds the plugins of `slurm-simulator/plugins`, renders the simulated cluster from the cookbook attributes and the config, replays the workload, then prints every job (partition, user, submit, start and end time, state, nodes), a summary of the waits, and the report of the run (see **Reports** below).
The results folder of a run is `<run>_<time>`: the run name (by default the workload and the config, e.g. `lab-sjf-4`) and the time the run started, in UTC and readable, e.g. `lab-sjf-4_2026-10-23_22-15-04`, so every run keeps its own results and repeated runs sort in time order.
It holds what produced it (`slurm.conf`, `gres.conf`, the config and the workload), the report (`report.png`, `report.pdf`, `summary.csv`) and the raw results: `jobcomp.log` (one line per finished job, which the report reads), `slurm_acct.out` (sacct of every job, `|`-separated), `slurmctld.log` and `sched.log` (the scheduler's decisions) and `slurmctld_log.csv` (scheduling events extracted from the log by the toolkit).

**The simulated cluster** has one partition, `main`, of one node set, `cmpt`: each node has 2 CPUs and 2048 MiB, like a lab compute node, and an `a100` and an `h100`, like a lab GPU node, so a node runs CPU and GPU jobs.
It is defined in `slurm-simulator/cookbook/attributes/default.rb` with the keys of the Slurm cluster's attributes (`slurm/cookbook/attributes/default.rb`): a node set's `replicas` (the number of nodes), `resources.limits` (its nodes' CPUs and memory), `gpus` (one entry per GPU, its type) and `features`, a partition's node sets and `configMap` (any [partition parameter](https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION)).
They belong to the simulator: changing them leaves the Slurm cluster alone.

**Configs** are JSON files in `slurm-simulator/configs`, one per experiment, whose attributes override the cookbook's for one run, merged key by key.
A config must declare the number of nodes, `replicas`, of every node set, so each experiment states its cluster; a run whose config does not fails, naming the node sets.
`make simulate-slurm` uses `baseline.json` unless given another:

- `baseline.json`: four nodes in `main`, and the lab's scheduling policy;
- `sjf-4.json`: the same four nodes, and the Shortest Job First policy (see **Custom policies** below).

```json
{
  "hpc-lab-slurm-simulator": {
    "nodesets": { "cmpt": { "replicas": 4 } },
    "slurm_conf": { "PriorityType": "priority/sjf" }
  }
}
```

A config can also change the nodes themselves, e.g. a hundred nodes with 64 CPUs, 256 GiB and four `a100` each: `"cmpt": { "replicas": 100, "gpus": ["a100", "a100", "a100", "a100"], "resources": { "limits": { "cpu": "64", "memory": "256Gi" } } }`.

**Reports** plot a run, or compare runs, in one PNG: CPU, memory and GPU utilization over time (the share of the cluster's CPUs, memory and GPUs allocated to running jobs), throughput (jobs completed per hour, counted in windows of the same length for every run: the shortest of 1, 2, 5, 10, 15, 30 minutes, 1 hour or more that splits the longest run in at most 20), jobs completed over time and a table per run of the policy, the cluster size, the mean utilizations, the throughput in jobs per hour, the mean, median and 95th percentile time to completion, and the makespan.
`make simulate-slurm` writes the report of its run, `results/<run>_<time>/report.png`, and `report.pdf` in vector for papers, with its table in `summary.csv`; `make report-slurm` compares runs, up to eight, each with its own color (Material Design hues) and line style, so the figure reads in grayscale too. The figure has the style of a paper's: a Times-like serif font (STIX), lettered panels in closed boxes with inward ticks, and a table with horizontal rules only.
A run is a run name, for its latest folder, or a folder, for that one:

```shell
make report-slurm runs="lab-baseline lab-sjf-4"                  # the latest of each, in results/lab-baseline_vs_lab-sjf-4_<time>.png, .pdf and .csv
make report-slurm runs="lab-baseline_2026-10-23_22-15-04 lab-baseline"   # an earlier baseline run against the latest
```

The report reads each run's `jobcomp.log` and its copy of `slurm.conf`, so runs on different clusters compare by the share of their own cluster.

**The scheduling policy** is the `slurm_conf` attributes, spelled out in `slurm-simulator/cookbook/templates/slurm.conf.erb`: the scheduler (`SchedulerType`, `SchedulerParameters`), resource selection (`SelectType`, `SelectTypeParameters`, `DefMemPerCPU`) and job priority (`PriorityType` and the `PriorityWeight*` factors).
By default it is the lab's: copied from the Slurm cluster's `slurm_conf` attributes, with the settings it leaves to Slurm's defaults written out with those defaults, `priority/multifactor` with every weight 0, so every job has the same priority and jobs run in submission order, with backfill.
To compare policies, run the same workload under a config for each one and compare the runs with `make report-slurm`.

**Custom policies** are Slurm plugins: every `slurm-simulator/plugins/<type>_<name>.c` is built into the simulator as the plugin `<type>/<name>` (rebuilt when the source changes), and the matching `slurm_conf` attribute selects it.
The sample, `priority_sjf.c`, is the simplest one, Shortest Job First: a priority plugin whose `priority_p_set` gives a job the priority 1000000 minus its time limit in minutes, so the shortest jobs start first.
To make the simulated Slurm use it, select the priority plugin, `"PriorityType": "priority/sjf"`, in a config (`sjf-4.json`), and compare it with the baseline:

```shell
make simulate-slurm                      # the lab's policy on four nodes, results in .../lab-baseline_<time>
make simulate-slurm config=sjf-4.json    # Shortest Job First on the same nodes, results in .../lab-sjf-4_<time>
make report-slurm runs="lab-baseline lab-sjf-4"
```

`lab.events` is the case Shortest Job First is for: a full cluster with short jobs queued behind long ones.
With the lab's policy every job has the same priority, so the second batch of hour-long jobs starts before the short ones, which wait for about two hours, and backfill cannot run them earlier, as no node is ever idle.
Shortest Job First runs the short jobs first: the mean time to completion drops from 124.0 to 81.2 minutes and the median from 130.6 to 72.9, 28 of the 32 jobs are done by 1.6 hours instead of 2.5, while utilization (98 %), throughput (12.5 jobs/h) and makespan (2.6 hours) stay the same; the cost is the long jobs of the second batch, which finish later (95th percentile 147.1 to 152.0 minutes).
`slurmctld.log` shows each job's priority (`priority/sjf: initial priority for job 9 is 999992`, an 8-minute job).
A new policy starts as a copy of `priority_sjf.c` under another name, `priority_<name>.c` with `plugin_type` `priority/<name>`, and changes `priority_p_set`; the same works for other plugin types, e.g. a scheduler (`sched_<name>.c` for `SchedulerType=sched/<name>`), starting from the simulator's own plugins in `/var/chef/cache/slurm-simulator/src/plugins` in the container.
A plugin that does not compile fails `make simulate-slurm` with the compiler errors.

**Workloads** are events files in `slurm-simulator/workloads`, one job submission per line:

```
-dt 0 -e submit_batch_job | -J jobid_1 -sim-walltime 600 --uid=user1 -A account1 -p main -q normal -t 00:15:00 -n 2 --ntasks-per-node=2 pseudo.job
```

Before `|`: when the job is submitted (`-dt`, seconds from the start of the workload) and the event type.
After it: the job, in `sbatch` arguments plus `-J jobid_<n>` (the name the toolkit matches results by), `-sim-walltime` (how long it runs, in seconds; above its time limit `-t` it ends in `TIMEOUT`), `--uid` (the user who submits it) and `pseudo.job` (the job script, which is not run).
The sample, `lab.events`, submits 32 jobs to `main`, all as `user1` charging `account1`, each taking a whole node (2 CPUs): first 8 hour-long GPU jobs (both GPUs of a node, time limit 65 minutes), one every 5 seconds, then from the first minute 24 short CPU jobs of 3 to 8 minutes, one every 10 seconds, whose time limits are their run time rounded up plus 2 minutes, so the time limits are good estimates of the run times.
The simulated cluster also knows `user2` (`account1`), `user3` and `user4` (`account2`) (`users.sim.erb` and `sacctmgr.script.erb` in the cookbook templates), for workloads with several users.
Events files take no comments: the simulator would read a `#` line as an event.

Limits of the simulator that a workload must respect:

- A job the cluster cannot run is rejected at submission (`Requested node configuration is not available`) and would keep the simulator waiting for it forever: `make simulate-slurm` stops the simulation and names the job.
- An untyped GPU count larger than any single type of a node, e.g. `--gres=gpu:2` on nodes with an `a100` and an `h100`, is rejected; ask for each type, `--gres=gpu:a100:1,gpu:h100:1`, or use `--gpus=2`.

## Node image

Kubernetes publishes no node image.
https://kubernetes.io/releases/download/ offers the control-plane images on `registry.k8s.io`, which kubeadm pulls, and the kubeadm, kubelet and kubectl binaries and packages.
`kindest/node`, built by the Kubernetes SIGs kind project, bundles those binaries with systemd, containerd and the fixes needed to run kubelet inside a container (cgroup root, machine-id, mount propagation, DNS forwarding to Docker's resolver).
The trade-off: the image is maintained by kind rather than by the Kubernetes release team, and building it from official packages would mean rewriting those container fixes in this repository.

## Testing

`make test` runs Cookstyle (`make lint-chef`), ShellCheck on every shell script (`make lint-shell`), a check that every Makefile target has a `##` description for `make help` (`make lint-make`) and the ChefSpec unit tests of every cookbook (`make test-chef`). Cookstyle and ChefSpec run in the `cincproject/workstation` image and ShellCheck in `koalaman/shellcheck`, so neither Ruby nor ShellCheck is needed on the host; the 🧪 Test workflow runs the same targets on pull requests. ShellCheck finds the scripts by their shebang among the files tracked by git, and `.shellcheckrc` lists the checks disabled for the whole repo.
Specs live in `*/cookbook/spec/unit/recipes/` and converge the recipes in memory against RHEL 9 (admin, slurm), Debian 13 (kubernetes) or Ubuntu 22.04 (slurm-simulator) platform data.
`make test-kubernetes` and `make test-slurm` are the live checks: API server and node readiness, and a hello world batch job whose output is read from `/shared`; `make simulate-slurm` is the live check of the simulator, failing if the sample workload does not run to the end.

## Release

Update `VERSION` and `CHANGELOG.md`, then:

```shell
VERSION="$(cat VERSION)"
gh release create v${VERSION} --title v${VERSION} --target main --notes-file CHANGELOG.md --latest --draft
gh release edit v${VERSION} --draft=false
```
