# Deploy the Slurm layer: cert-manager, the Slinky operator and the Slurm cluster,
# then wait until every compute node has registered idle.
slurm = node['hpc-lab-slurm']
config_dir = "#{slurm['home']}/slurm"
values = "#{config_dir}/slurm-chart-values.yaml"
conf_file = "#{config_dir}/slurm.conf"
# Extra config files, mounted next to slurm.conf (chart value configFiles).
config_files = %w(cgroup.conf).to_h { |name| [name, "#{config_dir}/#{name}"] }
stamp = "#{Chef::Config[:file_cache_path]}/slurm-values.sha256"
compute_nodes = slurm['nodesets'].values.sum { |set| set['replicas'] }
# --responding leaves out stale records of nodes that no longer exist.
idle_nodes = 'slurm-exec sinfo --responding -h -N -t idle -o %n 2>/dev/null | sort -u | wc -l'

# A release is up to date when `helm list` shows it deployed with chart <name>-<version>.
deployed = ->(namespace, chart, version) { "helm -n #{namespace} list --deployed -o json | jq -e 'any(.[]; .chart == \"#{chart.split('/').last}-#{version}\")' >/dev/null" }
pods_on_failure = ->(namespace) { "|| { kubectl -n #{namespace} get pods >&2; exit 1; }" }

# Node settings each nodeset passes to slurmd --conf (extraConfMap). RealMemory is
# the memory limit of the slurmd container, in MiB: slurmd would otherwise report
# the memory of the whole Docker host, and Slurm would schedule jobs the pod cannot run.
mebibytes = lambda do |quantity|
  match = /\A(\d+)(Mi|Gi)\z/.match(quantity.to_s) || raise("memory limit #{quantity.inspect}: use Mi or Gi")
  match[1].to_i * (match[2] == 'Gi' ? 1024 : 1)
end
node_conf = slurm['nodesets'].map do |name, set|
  memory = set.dig('resources', 'limits', 'memory')
  conf = {}
  conf['RealMemory'] = mebibytes[memory].to_s if memory
  conf['Features'] = set['features'].to_a if set['features']
  [name, conf]
end.to_h

directory config_dir do
  recursive true
end

template values do
  source 'slurm-chart-values.yaml.erb'
  variables(slurm: slurm, node_conf: node_conf)
end

template conf_file do
  source 'slurm.conf.erb'
  variables(conf: slurm['slurm_conf'])
end

config_files.each_value do |path|
  template path do
    source "#{::File.basename(path)}.erb"
  end
end

[
  ['cert-manager', 'cert-manager', 'oci://quay.io/jetstack/charts/cert-manager', slurm['cert_manager_version'], '--set crds.enabled=true --wait'],
  ['slurm-operator-crds', 'slinky', 'oci://ghcr.io/slinkyproject/charts/slurm-operator-crds', slurm['slinky_version'], ''],
  ['slurm-operator', 'slinky', 'oci://ghcr.io/slinkyproject/charts/slurm-operator', slurm['slinky_version'], '--wait'],
].each do |release, namespace, chart, version, flags|
  execute "helm upgrade --install #{release}" do
    command "helm upgrade --install #{release} #{chart} --version #{version} --namespace #{namespace} --create-namespace --timeout 10m #{flags} #{pods_on_failure[namespace]}"
    live_stream true
    not_if deployed[namespace, chart, version]
  end
end

# helm list tells the chart version of a release, not the values it was installed
# with. The stamp holds the checksums of the chart values, slurm.conf and the extra
# config files of the last successful upgrade: the upgrade re-runs when one changed or the
# release is not deployed, and is skipped otherwise, so a reconverge leaves the
# Slurm pods alone. A template notification would miss the retry after a failed
# upgrade, since the files no longer change.
# The operator restarts slurmctld when slurm.conf changes, not when only the extra
# config files do: once the controller sees the new files (the kubelet refreshes
# the mounted config map within a minute or so), scontrol reconfigure makes it, and
# through configless every slurmd, read them. Both are retried together, since the
# controller may be restarting for a slurm.conf change at the same time.
stamped = [values, conf_file, *config_files.values].join(' ')
# Helm reads a dot in a value name as nesting: configFiles.cgroup\.conf.
set_config_files = config_files.map { |name, path| "--set-file 'configFiles.#{name.gsub('.', '\\\\.')}=#{path}'" }.join(' ')
controller_has = config_files.map do |name, path|
  "[ \"$(kubectl -n slurm exec slurm-controller-0 -c slurmctld -- cat /etc/slurm/#{name} 2>/dev/null)\" = \"$(cat #{path})\" ]"
end.join(' && ')
execute 'helm upgrade --install slurm' do
  command "helm upgrade --install slurm oci://ghcr.io/slinkyproject/charts/slurm --version #{slurm['slinky_version']} --namespace slurm --create-namespace --timeout 15m" \
          " -f #{values} --set-file controller.extraConf=#{conf_file} #{set_config_files}" \
          " && timeout 300 bash -c 'until #{controller_has} && slurm-exec scontrol reconfigure; do sleep 5; done'" \
          " && sha256sum #{stamped} > #{stamp} #{pods_on_failure['slurm']}"
  live_stream true
  not_if "#{deployed['slurm', 'oci://ghcr.io/slinkyproject/charts/slurm', slurm['slinky_version']]} && sha256sum -c --status #{stamp}"
end

# Ready means Slurm itself says so: every compute node registered and idle.
execute "wait for #{compute_nodes} idle Slurm nodes" do
  command "timeout 900 bash -c 'until [ \"$(#{idle_nodes})\" -eq #{compute_nodes} ]; do sleep 10; done' #{pods_on_failure['slurm']}"
  not_if "[ \"$(#{idle_nodes})\" -eq #{compute_nodes} ]"
end
