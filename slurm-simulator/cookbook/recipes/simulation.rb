# The simulated cluster, rendered from the attributes into slurm-simulator/etc, and
# slurm-simulate, which runs a simulation on it. slurm-simulate converges this
# recipe first, so an attribute change applies to the next simulation.
simulator = node['hpc-lab-slurm-simulator']
sim_home = "#{simulator['home']}/slurm-simulator"
etc = "#{sim_home}/etc"

# The node sets and partitions use the keys of the lab cluster (hpc-lab-slurm), which
# describe pods; here they become slurm.conf nodes and partitions. A node gets the CPU
# and memory limits of its node set, as Slinky gives each lab node, in whole CPUs and MiB.
cpus = lambda do |name, quantity|
  /\A\d+\z/.match?(quantity.to_s) || raise("node set #{name}: cpu limit #{quantity.inspect}: the simulator needs whole CPUs")
  quantity.to_i
end
mebibytes = lambda do |name, quantity|
  match = /\A(\d+)(Mi|Gi)\z/.match(quantity.to_s) || raise("node set #{name}: memory limit #{quantity.inspect}: use Mi or Gi")
  match[1].to_i * (match[2] == 'Gi' ? 1024 : 1)
end
# A simulation states its cluster: its config (slurm-simulate) declares the number of
# nodes, replicas, of every node set, rather than inheriting it from the attributes.
# The config's attributes are the normal ones (cinc-client -j), over the cookbook's
# default ones: this reads them, which the cop against setting them does not tell apart.
if simulator['config']
  undeclared = simulator['nodesets'].keys.reject { |name| node.normal.dig('hpc-lab-slurm-simulator', 'nodesets', name, 'replicas') } # rubocop:disable Chef/Correctness/NodeNormal
  raise "config #{simulator['config']}: declare the replicas of node sets #{undeclared.join(', ')}" unless undeclared.empty?
end
# One entry per node set: cmpt => { hostlist cmpt-[0-3], cpus 2, memory 2048, ... }.
nodesets = simulator['nodesets'].map do |name, set|
  /\A[1-9]\d*\z/.match?(set['replicas'].to_s) || raise("node set #{name}: replicas #{set['replicas'].inspect}: use a whole number, at least 1")
  limits = set.dig('resources', 'limits') || {}
  raise "node set #{name}: the simulator needs resources.limits.cpu and resources.limits.memory" unless limits['cpu'] && limits['memory']
  [name, {
    'hostlist' => "#{name}-[0-#{set['replicas'] - 1}]",
    'cpus' => cpus[name, limits['cpu']],
    'memory' => mebibytes[name, limits['memory']],
    'features' => set['features'].to_a,
    # Gres=gpu:a100:1,gpu:h100:1: the count of each GPU type, in the order of the list.
    'gpus' => set['gpus'].to_a.tally,
  }]
end.to_h
# The enabled partitions and the nodes of their node sets.
partitions = simulator['partitions'].select { |_name, partition| partition['enabled'] }.map do |name, partition|
  [name, {
    'nodes' => partition['nodesets'].map { |set| nodesets.fetch(set) { raise "partition #{name}: no node set #{set}" }['hostlist'] }.join(','),
    'config' => partition['configMap'].to_h,
  }]
end.to_h

remote_directory '/usr/local/bin' do
  source 'usr/local/bin'
  files_mode '0755'
end

directory etc

%w(slurm.conf gres.conf slurmdbd.conf sim.conf users.sim sacctmgr.script).each do |name|
  template "#{etc}/#{name}" do
    source "#{name}.erb"
    variables(simulator: simulator, sim_home: sim_home, nodesets: nodesets, partitions: partitions)
    # slurmdbd refuses a slurmdbd.conf others can read: it holds the database password.
    mode name == 'slurmdbd.conf' ? '0600' : '0644'
  end
end
