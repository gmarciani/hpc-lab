# Lab folder inside the container: chef/ (client.rb and the mounted cookbook) and
# slurm-simulator/ (the simulator build, the simulated cluster configuration, and
# the workloads, plugins and results folders mounted from slurm-simulator/ on the host).
default['hpc-lab-slurm-simulator']['home'] = '/opt/hpc-lab'
# UB CCR Slurm Simulator: https://github.com/ubccr-slurm-simulator/slurm_sim_tools
# Release of the toolkit (slurmsim, which runs a simulation) and commit of the
# simulator it pins as a submodule: Slurm 23.02 modified to simulate its scheduling
# (branch slurm-23-02-sim of https://github.com/ubccr-slurm-simulator/slurm_simulator).
# Both are built once; a change needs a new container (make redeploy-slurm-simulator).
default['hpc-lab-slurm-simulator']['sim_tools_version'] = '3.0'
default['hpc-lab-slurm-simulator']['simulator_commit'] = 'f99a71eb2073266bba3869aa2a0ccd51c58c9bb7'

# The config of the simulation being run, a file of slurm-simulator/configs, which
# slurm-simulate sets with the config's attributes; none outside a simulation.
default['hpc-lab-slurm-simulator']['config'] = nil

# --- The simulated cluster ----------------------------------------------------
# One partition, main, of one node set, cmpt: each node has the CPUs and memory of a
# lab compute node and the GPUs of a lab GPU node, an a100 and an h100. A
# simulation's config (slurm-simulator/configs) declares how many nodes (replicas).
# The keys are the hpc-lab-slurm ones (slurm/cookbook/attributes/default.rb): replicas,
# features, gpus and resources.limits (cpu and memory, which Slinky also gives each lab
# node as its CPUs and memory) of a node set; enabled, nodesets and configMap of a
# partition. They belong to the simulator: changing them leaves the lab cluster alone.
default['hpc-lab-slurm-simulator']['cluster_name'] = 'hpc-lab'
default['hpc-lab-slurm-simulator']['nodesets'] = {
  'cmpt' => {
    'replicas' => 4,
    'gpus' => %w(a100 h100),
    'resources' => {
      'limits' => {
        'cpu' => '2',
        'memory' => '2Gi',
      },
    },
  },
}
default['hpc-lab-slurm-simulator']['partitions'] = {
  'main' => {
    'enabled' => true,
    'nodesets' => %w(cmpt),
    'configMap' => {
      'Default' => 'YES',
      'MaxTime' => 'UNLIMITED',
    },
  },
}
# The scheduling settings of the lab cluster, copied from the hpc-lab-slurm slurm_conf
# attributes (2026-10-18); a config can change any of them for a run.
# TaskPlugin is copied too but not used: the simulator confines no process (task/none).
default['hpc-lab-slurm-simulator']['slurm_conf']['MinJobAge'] = 600
default['hpc-lab-slurm-simulator']['slurm_conf']['SchedulerType'] = 'sched/backfill'
default['hpc-lab-slurm-simulator']['slurm_conf']['SelectType'] = 'select/cons_tres'
default['hpc-lab-slurm-simulator']['slurm_conf']['SelectTypeParameters'] = 'CR_Core_Memory'
default['hpc-lab-slurm-simulator']['slurm_conf']['DefMemPerCPU'] = 1024
default['hpc-lab-slurm-simulator']['slurm_conf']['TaskPlugin'] = 'task/cgroup,task/affinity'

# --- The scheduling policy under study -------------------------------------------
# Settings the lab cluster leaves to Slurm's defaults (neither hpc-lab-slurm nor the
# Slinky operator sets them), written out with the values the lab gets, since the
# simulator's Slurm 23.02 defaults differ from the lab's 26.05 (PriorityType there is
# priority/basic). With every weight 0 all jobs have the same priority, so the lab runs
# them in submission order, with backfill. Reference: https://slurm.schedmd.com/slurm.conf.html
default['hpc-lab-slurm-simulator']['slurm_conf']['SchedulerParameters'] = 'bf_interval=30,bf_window=1440,sched_interval=60'
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityType'] = 'priority/multifactor'
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityDecayHalfLife'] = '7-0'
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityMaxAge'] = '7-0'
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityWeightAge'] = 0
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityWeightFairshare'] = 0
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityWeightJobSize'] = 0
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityWeightPartition'] = 0
default['hpc-lab-slurm-simulator']['slurm_conf']['PriorityWeightQOS'] = 0
