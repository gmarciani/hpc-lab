# Lab folder inside the container: chef/client.rb and the mounted cookbook.
default['hpc-lab-k8s']['home'] = '/opt/hpc-lab'
# Must match the kindest/node tag in k8s/Dockerfile; the first boot checks it.
default['hpc-lab-k8s']['kubernetes_version'] = 'v1.36.4'
default['hpc-lab-k8s']['cluster_name'] = 'hpc-lab'
# Hostname of the control-plane service in docker-compose.yaml and its API port.
default['hpc-lab-k8s']['control_plane_host'] = 'k8s-control-plane'
default['hpc-lab-k8s']['api_port'] = 6443
# service_subnet must not overlap pod_subnet or the Docker network of the nodes.
default['hpc-lab-k8s']['pod_subnet'] = '10.244.0.0/16'
default['hpc-lab-k8s']['service_subnet'] = '10.96.0.0/16'
