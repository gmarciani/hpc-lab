# Lab folder inside the container: chef/client.rb and the mounted cookbook.
default['hpc-lab-kubernetes']['home'] = '/opt/hpc-lab'
# Must match the kindest/node tag in kubernetes/Dockerfile; the first boot checks it.
default['hpc-lab-kubernetes']['kubernetes_version'] = 'v1.36.4'
default['hpc-lab-kubernetes']['cluster_name'] = 'hpc-lab'
# Hostname of the control-plane service in docker-compose.yaml and its API port.
default['hpc-lab-kubernetes']['control_plane_host'] = 'kubernetes-control-plane'
default['hpc-lab-kubernetes']['api_port'] = 6443
# `name:` of docker-compose.yaml, the prefix of the container names.
default['hpc-lab-kubernetes']['compose_project'] = 'hpc-lab'
# service_subnet must not overlap pod_subnet or the Docker network of the nodes.
default['hpc-lab-kubernetes']['pod_subnet'] = '10.244.0.0/16'
default['hpc-lab-kubernetes']['service_subnet'] = '10.96.0.0/16'
