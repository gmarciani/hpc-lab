require 'spec_helper'

describe 'hpc-lab-slurm-simulator::simulation' do
  let(:attrs) { {} }
  let(:etc) { '/opt/hpc-lab/slurm-simulator/etc' }
  let(:chef_run) do
    ChefSpec::SoloRunner.new { |node| attrs.each { |key, value| node.normal['hpc-lab-slurm-simulator'][key] = value } }.converge(described_recipe)
  end

  # The setting lines of a rendered file, without comments and blank lines.
  def settings(file)
    content = ''
    expect(chef_run).to render_file("#{etc}/#{file}").with_content { |rendered| content = rendered }
    content.lines(chomp: true).grep_v(/\A\s*(#|\z)/)
  end

  it 'installs slurm-simulate' do
    expect(chef_run).to create_remote_directory('/usr/local/bin').with(source: 'usr/local/bin', files_mode: '0755')
  end

  it 'simulates one partition, main, of four nodes with CPUs and GPUs by default' do
    expect(settings('slurm.conf')).to include('ClusterName=hpc-lab', 'GresTypes=gpu', 'AccountingStorageTRES=gres/gpu', 'MinJobAge=600')
    expect(settings('slurm.conf').grep(/^(NodeName|PartitionName)=/)).to eq(
      [
        'NodeName=cmpt-[0-3] CPUs=2 RealMemory=2048 Gres=gpu:a100:1,gpu:h100:1',
        'PartitionName=main Nodes=cmpt-[0-3] Default=YES MaxTime=UNLIMITED',
      ]
    )
    expect(settings('gres.conf')).to eq(
      [
        'AutoDetect=off',
        'NodeName=cmpt-[0-3] Name=gpu Type=a100 Count=1',
        'NodeName=cmpt-[0-3] Name=gpu Type=h100 Count=1',
      ]
    )
  end

  it 'schedules like the lab cluster by default: backfill, every job the same priority' do
    expect(settings('slurm.conf')).to include(
      'SchedulerType=sched/backfill',
      'SchedulerParameters=bf_interval=30,bf_window=1440,sched_interval=60',
      'SelectType=select/cons_tres',
      'SelectTypeParameters=CR_Core_Memory',
      'DefMemPerCPU=1024',
      'PriorityType=priority/multifactor',
      'PriorityWeightAge=0',
      'PriorityWeightFairshare=0',
      'PriorityWeightJobSize=0'
    )
  end

  it 'confines no process, whatever TaskPlugin the copy of the lab settings has' do
    expect(settings('slurm.conf')).to include('TaskPlugin=task/none')
    expect(settings('slurm.conf')).not_to include('TaskPlugin=task/cgroup,task/affinity')
  end

  it 'runs the daemons as root without authentication, keeping their files under the simulator folder' do
    expect(settings('slurm.conf')).to include(
      'SlurmUser=root',
      'AuthType=auth/none',
      'CredType=cred/none',
      'StateSaveLocation=/opt/hpc-lab/slurm-simulator/var/state',
      'JobCompLoc=/opt/hpc-lab/slurm-simulator/log/jobcomp.log'
    )
    expect(settings('slurmdbd.conf')).to include('SlurmUser=root', 'AuthType=auth/none', 'StorageUser=slurm', 'StorageLoc=slurm_acct_db')
  end

  it 'keeps slurmdbd.conf, which holds the database password, readable by root only' do
    expect(chef_run).to create_template("#{etc}/slurmdbd.conf").with(mode: '0600')
    expect(chef_run).to create_template("#{etc}/slurm.conf").with(mode: '0644')
  end

  it 'starts the simulated clock at a fixed time and exits once every job has finished' do
    expect(settings('sim.conf')).to include('TimeStart = 1640995200', 'TimeAfterAllEventsDone = 10')
  end

  it 'declares the users of the workloads and their accounts' do
    expect(settings('users.sim')).to eq(%w(user1:1001:group1:1001 user2:1002:group1:1001 user3:1003:group2:1002 user4:1004:group2:1002))
    expect(settings('sacctmgr.script')).to include(
      'add cluster Name=hpc-lab',
      'add user Name=user1 DefaultAccount=account1',
      'add user Name=user4 DefaultAccount=account2'
    )
  end

  context 'with the replicas of a config' do
    let(:attrs) { { 'config' => 'baseline.json', 'cluster_name' => 'big', 'nodesets' => { 'cmpt' => { 'replicas' => 100 } } } }

    it 'puts that many nodes in main' do
      expect(settings('slurm.conf')).to include(
        'ClusterName=big',
        'NodeName=cmpt-[0-99] CPUs=2 RealMemory=2048 Gres=gpu:a100:1,gpu:h100:1',
        'PartitionName=main Nodes=cmpt-[0-99] Default=YES MaxTime=UNLIMITED'
      )
      expect(settings('sacctmgr.script')).to include('add cluster Name=big')
    end
  end

  context 'with a config that does not declare the nodes of every node set' do
    let(:attrs) { { 'config' => 'partial.json', 'slurm_conf' => { 'PriorityType' => 'priority/sjf' } } }

    it 'fails naming the undeclared node sets' do
      expect { chef_run }.to raise_error(RuntimeError, /config partial.json: declare the replicas of node sets cmpt/)
    end
  end

  context 'with larger nodes without GPUs' do
    let(:attrs) { { 'nodesets' => { 'cmpt' => { 'gpus' => [], 'resources' => { 'limits' => { 'cpu' => '64', 'memory' => '256Gi' } } } } } }

    it 'declares no GPU resource' do
      expect(settings('slurm.conf')).to include('NodeName=cmpt-[0-3] CPUs=64 RealMemory=262144')
      expect(settings('slurm.conf')).not_to include('GresTypes=gpu', 'AccountingStorageTRES=gres/gpu')
      expect(settings('gres.conf')).to eq(['AutoDetect=off'])
    end
  end

  context 'with four GPUs of one type per node' do
    let(:attrs) { { 'nodesets' => { 'cmpt' => { 'gpus' => %w(a100 a100 a100 a100) } } } }

    it 'counts them by type' do
      expect(settings('slurm.conf')).to include('NodeName=cmpt-[0-3] CPUs=2 RealMemory=2048 Gres=gpu:a100:4')
      expect(settings('gres.conf')).to include('NodeName=cmpt-[0-3] Name=gpu Type=a100 Count=4')
    end
  end

  {
    'a fractional cpu limit' => [{ 'nodesets' => { 'cmpt' => { 'resources' => { 'limits' => { 'cpu' => '500m' } } } } }, /node set cmpt: cpu limit "500m": the simulator needs whole CPUs/],
    'a memory limit not in Mi or Gi' => [{ 'nodesets' => { 'cmpt' => { 'resources' => { 'limits' => { 'memory' => '2G' } } } } }, /node set cmpt: memory limit "2G": use Mi or Gi/],
    'a node set without limits' => [{ 'nodesets' => { 'gpu' => { 'replicas' => 3 } } }, /node set gpu: the simulator needs resources.limits.cpu and resources.limits.memory/],
    'a partition of an unknown node set' => [{ 'partitions' => { 'main' => { 'nodesets' => %w(nope) } } }, /partition main: no node set nope/],
    'a fractional number of nodes' => [{ 'nodesets' => { 'cmpt' => { 'replicas' => 2.5 } } }, /node set cmpt: replicas 2.5: use a whole number, at least 1/],
    'no nodes' => [{ 'nodesets' => { 'cmpt' => { 'replicas' => 0 } } }, /node set cmpt: replicas 0: use a whole number, at least 1/],
  }.each do |problem, (problem_attrs, message)|
    context "with #{problem}" do
      let(:attrs) { problem_attrs }

      it 'fails naming it' do
        expect { chef_run }.to raise_error(RuntimeError, message)
      end
    end
  end

  {
    'first in, first out' => { 'SchedulerType' => 'sched/builtin', 'PriorityType' => 'priority/basic' },
    'fairshare only' => { 'PriorityWeightAge' => 0, 'PriorityWeightFairshare' => 100_000, 'PriorityWeightJobSize' => 0 },
    'shortest job first, the custom plugin' => { 'PriorityType' => 'priority/sjf' },
  }.each do |policy, slurm_conf|
    context "with the #{policy} policy" do
      let(:attrs) { { 'slurm_conf' => slurm_conf } }

      it 'renders its settings' do
        expect(settings('slurm.conf')).to include(*slurm_conf.map { |key, value| "#{key}=#{value}" })
      end
    end
  end
end
