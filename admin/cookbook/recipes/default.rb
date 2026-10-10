# Container start of the admin node: everything but the entrypoint, which the
# Dockerfile copies. files/ and templates/ mirror the target filesystem and each
# files/ directory is copied whole.
include_recipe 'hpc-lab-admin::dependencies'
include_recipe 'hpc-lab-admin::ssh'
include_recipe 'hpc-lab-admin::libraries'
