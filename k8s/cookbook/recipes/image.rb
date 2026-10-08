# Image build of a Kubernetes node: only what systemd needs before the first
# converge can run, the unit that runs it. Everything else is in the default recipe.
template '/etc/systemd/system/k8s-bootstrap.service' do
  source 'etc/systemd/system/k8s-bootstrap.service.erb'
  variables(hpc_lab_home: node['hpc-lab-k8s']['home'])
end

# systemd is not running during `docker build`: enable works offline, daemon-reload does not.
systemd_unit 'k8s-bootstrap.service' do
  triggers_reload false
  action :enable
end
