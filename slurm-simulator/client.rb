# Cinc Client configuration of the slurm-simulator node: local mode, no Chef server.
# Cookbooks come from /opt/hpc-lab/chef/cookbooks, mounted read-only at runtime.
local_mode true
chef_repo_path '/opt/hpc-lab/chef'
file_cache_path '/var/chef/cache'
node_path '/var/chef/nodes'
log_location STDOUT
