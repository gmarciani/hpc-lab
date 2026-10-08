# Deploy the Slurm layer: cert-manager, the Slinky operator and the Slurm cluster,
# then wait until every compute node has registered idle.
slurm = node['hpc-lab-slurm']
config_dir = "#{slurm['home']}/slurm"
values = "#{config_dir}/slurm-chart-values.yaml"
conf_file = "#{config_dir}/slurm.conf"
stamp = "#{Chef::Config[:file_cache_path]}/slurm-values.sha256"
compute_nodes = slurm['nodesets'].values.sum { |set| set['replicas'] }
# --responding leaves out stale records of nodes that no longer exist.
idle_nodes = 'slurm-exec sinfo --responding -h -N -t idle -o %n 2>/dev/null | sort -u | wc -l'

# A release is up to date when `helm list` shows it deployed with chart <name>-<version>.
deployed = ->(namespace, chart, version) { "helm -n #{namespace} list --deployed -o json | jq -e 'any(.[]; .chart == \"#{chart.split('/').last}-#{version}\")' >/dev/null" }
pods_on_failure = ->(namespace) { "|| { kubectl -n #{namespace} get pods >&2; exit 1; }" }

directory config_dir do
  recursive true
end

template values do
  source 'slurm-chart-values.yaml.erb'
  variables(slurm: slurm)
end

template conf_file do
  source 'slurm.conf.erb'
  variables(conf: slurm['slurm_conf'])
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
# with. The stamp holds the checksums of the chart values and slurm.conf of the
# last successful upgrade: the upgrade re-runs when either file changed or the
# release is not deployed, and is skipped otherwise, so a reconverge leaves the
# Slurm pods alone. A template notification would miss the retry after a failed
# upgrade, since the files no longer change.
execute 'helm upgrade --install slurm' do
  command "helm upgrade --install slurm oci://ghcr.io/slinkyproject/charts/slurm --version #{slurm['slinky_version']} --namespace slurm --create-namespace --timeout 15m" \
          " -f #{values} --set-file controller.extraConf=#{conf_file} && sha256sum #{values} #{conf_file} > #{stamp} #{pods_on_failure['slurm']}"
  live_stream true
  not_if "#{deployed['slurm', 'oci://ghcr.io/slinkyproject/charts/slurm', slurm['slinky_version']]} && sha256sum -c --status #{stamp}"
end

# Ready means Slurm itself says so: every compute node registered and idle.
execute "wait for #{compute_nodes} idle Slurm nodes" do
  command "timeout 900 bash -c 'until [ \"$(#{idle_nodes})\" -eq #{compute_nodes} ]; do sleep 10; done' #{pods_on_failure['slurm']}"
  not_if "[ \"$(#{idle_nodes})\" -eq #{compute_nodes} ]"
end
