# Cinc Client configuration of a Kubernetes node: local mode, no Chef server. Cookbooks
# come from /opt/hpc-lab/chef/cookbooks, mounted read-only at image build and at
# runtime.
local_mode true
chef_repo_path '/opt/hpc-lab/chef'
file_cache_path '/var/chef/cache'
node_path '/var/chef/nodes'
log_location STDOUT
