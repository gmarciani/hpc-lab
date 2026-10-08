# Lab folder inside the container: chef/ (client.rb and the mounted cookbooks) and
# ssh/ (the keypair mounted from admin/ssh).
default['hpc-lab-admin']['home'] = '/opt/hpc-lab'
# Within one minor of the Kubernetes version (hpc-lab-k8s kubernetes_version).
default['hpc-lab-admin']['kubectl_version'] = '1.36.4'
default['hpc-lab-admin']['helm_version'] = '3.22.0'
