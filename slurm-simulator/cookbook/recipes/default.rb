# Container start of the slurm-simulator node: everything but the entrypoint, which
# the Dockerfile copies. files/ and templates/ mirror the target filesystem and each
# files/ directory is copied whole.
include_recipe 'hpc-lab-slurm-simulator::dependencies'
include_recipe 'hpc-lab-slurm-simulator::simulator'
include_recipe 'hpc-lab-slurm-simulator::plugins'
include_recipe 'hpc-lab-slurm-simulator::database'
include_recipe 'hpc-lab-slurm-simulator::simulation'
