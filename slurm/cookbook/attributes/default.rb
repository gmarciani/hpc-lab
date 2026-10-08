# Lab folder inside the admin container; the deploy recipe writes slurm/ in it.
default['hpc-lab-slurm']['home'] = '/opt/hpc-lab'
# cert-manager chart version; the Slinky operator needs it for its webhook certificates.
default['hpc-lab-slurm']['cert_manager_version'] = 'v1.21.2'
# Version of the Slinky charts: slurm-operator-crds, slurm-operator and slurm.
default['hpc-lab-slurm']['slinky_version'] = '1.2.3'
# Cluster shape, rendered into the slurm chart values (templates/slurm-chart-values.yaml.erb).
# Schema: https://github.com/SlinkyProject/slurm-operator/blob/v1.2.3/helm/slurm/README.md
default['hpc-lab-slurm']['cluster_name'] = 'hpc-lab'
default['hpc-lab-slurm']['loginsets'] = {
  'hpc' => {
    'replicas' => 1,
  },
}
# The operator names the compute nodes <nodeset>-<ordinal>, counting from 0:
# cmpt-0, cmpt-1 and cmpt-gpu-0, cmpt-gpu-1. The lab has no GPUs: cmpt-gpu nodes
# are CPU pods like the others, in their own partition.
default['hpc-lab-slurm']['nodesets'] = {
  'cmpt' => {
    'replicas' => 2,
    'resources' => {
      'requests' => {
        'cpu' => '1',
        'memory' => '1Gi',
      },
      'limits' => {
        'cpu' => '2',
        'memory' => '2Gi',
      },
    },
  },
  'cmpt-gpu' => {
    'replicas' => 2,
    # Slurm node features (jobs select them with --constraint); the operator adds the
    # nodeset name. The controller keeps node records across make stop-slurm, so a
    # change reaches existing nodes only after make clean (or deleting their records).
    'features' => %w(gpu),
    'resources' => {
      'requests' => {
        'cpu' => '1',
        'memory' => '1Gi',
      },
      'limits' => {
        'cpu' => '2',
        'memory' => '2Gi',
      },
    },
  },
}
# Slurm partitions (queues) and the nodesets in each; main is the default one.
default['hpc-lab-slurm']['partitions'] = {
  'main' => {
    'enabled' => true,
    'nodesets' => %w(cmpt),
    'configMap' => {
      'Default' => 'YES',
      'MaxTime' => 'UNLIMITED',
    },
  },
  'main-gpu' => {
    'enabled' => true,
    'nodesets' => %w(cmpt-gpu),
    'configMap' => {
      'MaxTime' => 'UNLIMITED',
    },
  },
}
# slurm.conf settings appended to the configuration the operator generates
# (templates/slurm.conf.erb). Reference: https://slurm.schedmd.com/slurm.conf.html
default['hpc-lab-slurm']['slurm_conf']['MinJobAge'] = 600
default['hpc-lab-slurm']['slurm_conf']['SchedulerType'] = 'sched/backfill'
default['hpc-lab-slurm']['slurm_conf']['SelectType'] = 'select/cons_tres'
default['hpc-lab-slurm']['slurm_conf']['SelectTypeParameters'] = 'CR_Core_Memory'
