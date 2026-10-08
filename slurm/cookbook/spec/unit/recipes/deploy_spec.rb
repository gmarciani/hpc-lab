require 'spec_helper'

describe 'hpc-lab-slurm::deploy' do
  let(:attrs) { {} }
  let(:deployed) { false }
  let(:idle) { false }
  let(:values) { '/opt/hpc-lab/slurm/slurm-chart-values.yaml' }
  let(:chef_run) do
    ChefSpec::SoloRunner.new { |node| attrs.each { |key, value| node.normal['hpc-lab-slurm'][key] = value } }.converge(described_recipe)
  end

  # The Helm releases the converge installs or upgrades, in order.
  def upgraded_releases
    %w(cert-manager slurm-operator-crds slurm-operator slurm).select do |release|
      chef_run.execute("helm upgrade --install #{release}").performed_action?(:run)
    end
  end

  before do
    stub_command(/helm -n .* list --deployed/).and_return(deployed)
    stub_command(/slurm-exec sinfo/).and_return(idle)
  end

  it 'renders the chart values from the attributes' do
    expect(chef_run).to create_directory('/opt/hpc-lab/slurm').with(recursive: true)
    expect(chef_run).to render_file(values)
      .with_content(/^clusterName: hpc-lab$/)
      .with_content(/^  hpc:\n    replicas: 1$/)
      .with_content(%r{^    login: \{ volumeMounts: \[\{ name: shared, mountPath: /shared \}\] \}$})
      .with_content(/^  cmpt:\n    replicas: 2$/)
      .with_content(/resources: \{"requests":\{"cpu":"1","memory":"1Gi"\},"limits":\{"cpu":"2","memory":"2Gi"\}\}/)
      .with_content(/^  cmpt-gpu:\n    replicas: 2$/)
      .with_content(/^    extraConfMap: \{ Features: \["gpu"\] \}$/)
      .with_content(/^partitions: \{"main":\{"enabled":true,"nodesets":\["cmpt"\],"configMap":\{"Default":"YES","MaxTime":"UNLIMITED"\}\},"main-gpu":\{"enabled":true,"nodesets":\["cmpt-gpu"\],"configMap":\{"MaxTime":"UNLIMITED"\}\}\}$/)
  end

  {
    'mounts the shared directory on every login and compute node' => { 'hostPath: { path: /shared, type: Directory }' => 3, 'volumeMounts: [{ name: shared, mountPath: /shared }]' => 3 },
    'sets node features only on the node sets that have them' => { 'extraConfMap' => 1 },
  }.each do |behaviour, occurrences|
    it behaviour do
      expect(chef_run).to render_file(values).with_content { |content|
        occurrences.each { |snippet, count| expect(content.scan(snippet).size).to eq(count) }
      }
    end
  end

  it 'renders slurm.conf with the scheduler settings' do
    expect(chef_run).to render_file('/opt/hpc-lab/slurm/slurm.conf')
      .with_content(/^MinJobAge=600$/)
      .with_content(%r{^SchedulerType=sched/backfill$})
      .with_content(%r{^SelectType=select/cons_tres$})
      .with_content(/^SelectTypeParameters=CR_Core_Memory$/)
  end

  it 'installs cert-manager, the operator CRDs, the operator and slurm with the attribute versions' do
    expect(upgraded_releases).to eq(%w(cert-manager slurm-operator-crds slurm-operator slurm))
    expect(chef_run).to run_execute('helm upgrade --install cert-manager')
      .with(command: %r{^helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager --version v1.21.2 --namespace cert-manager .* --set crds.enabled=true --wait })
    expect(chef_run).to run_execute('helm upgrade --install slurm-operator-crds').with(command: /slurm-operator-crds --version 1.2.3 --namespace slinky /)
    expect(chef_run).to run_execute('helm upgrade --install slurm-operator').with(command: /slurm-operator --version 1.2.3 --namespace slinky .* --wait /)
    expect(chef_run).to run_execute('helm upgrade --install slurm')
      .with(command: %r{charts/slurm --version 1.2.3 --namespace slurm .* -f #{values} --set-file controller.extraConf=/opt/hpc-lab/slurm/slurm.conf && sha256sum })
  end

  it 'waits for every compute node to be idle' do
    expect(chef_run).to run_execute('wait for 4 idle Slurm nodes').with(command: /timeout 900 bash -c 'until \[ "\$\(slurm-exec sinfo .*\)" -eq 4 \]/)
  end

  context 'when the releases are deployed and the nodes idle' do
    let(:deployed) { true }
    let(:idle) { true }
    let(:unchanged) { true }

    # Registered after the helm stub, so it answers the slurm guard: deployed && stamp matches.
    before { stub_command(/sha256sum -c --status/).and_return(unchanged) }

    it 'runs nothing' do
      expect(upgraded_releases).to be_empty
      expect(chef_run).not_to run_execute('wait for 4 idle Slurm nodes')
    end

    context 'but the chart values or slurm.conf changed' do
      let(:unchanged) { false }

      it 'upgrades only the slurm release' do
        expect(upgraded_releases).to eq(%w(slurm))
      end
    end
  end

  context 'with two node sets and another MinJobAge' do
    let(:attrs) { { 'nodesets' => { 'gpu' => { 'replicas' => 3 } }, 'slurm_conf' => { 'MinJobAge' => 60 } } }

    it 'follows the attributes' do
      expect(chef_run).to render_file(values).with_content(/^  gpu:\n    replicas: 3\n    slurmd:\n      resources: null$/)
      expect(chef_run).to run_execute('wait for 7 idle Slurm nodes')
      expect(chef_run).to render_file('/opt/hpc-lab/slurm/slurm.conf').with_content(/^MinJobAge=60$/)
    end
  end
end
