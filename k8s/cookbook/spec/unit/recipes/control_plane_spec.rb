require 'spec_helper'

describe 'hpc-lab-k8s::control_plane' do
  let(:bootstrapped) { false }
  let(:applied) { false }
  let(:etcd_data) { false }
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before do
    stub_command(/kubeadm token list|kubectl/).and_return(applied)
    stub_file(:read, '/etc/kubernetes/admin.conf', 'admin kubeconfig')
    stub_file(:exist?, '/etc/kubernetes/kubelet.conf', bootstrapped)
    stub_file(:directory?, '/var/lib/etcd/member', etcd_data)
  end

  it 'runs kubeadm init with the configuration file' do
    expect(chef_run).to run_execute('kubeadm init').with(command: 'kubeadm init --config /etc/kubeadm.conf --skip-token-print')
    expect(chef_run).not_to run_ruby_block('refuse to re-init over existing etcd data')
  end

  it 'creates the bootstrap token from the environment, against the admin kubeconfig' do
    expect(chef_run).to run_execute('kubeadm token create')
      .with(command: 'kubeadm token create "$K8S_TOKEN" --ttl 0', environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' })
  end

  it 'applies the CNI with the pod subnet and the storage class' do
    expect(chef_run).to run_execute('kubectl apply cni').with(command: %r{sed 's\|\{\{ \.PodSubnet \}\}\|10\.244\.0\.0/16\|g' .* \| kubectl apply -f -})
    expect(chef_run).to run_execute('kubectl apply storage')
  end

  it 'exports the admin kubeconfig without logging it' do
    expect(chef_run).to create_file('/output/config').with(mode: '0644', sensitive: true, content: 'admin kubeconfig')
  end

  context 'when the node is already bootstrapped' do
    let(:bootstrapped) { true }

    it 'skips kubeadm init' do
      expect(chef_run).not_to run_execute('kubeadm init')
    end
  end

  context 'when the token, the CNI and the storage class exist' do
    let(:applied) { true }

    it 'skips creating them again' do
      expect(chef_run).not_to run_execute('kubeadm token create')
      expect(chef_run).not_to run_execute('kubectl apply cni')
      expect(chef_run).not_to run_execute('kubectl apply storage')
    end
  end

  context 'when etcd data exists but the node is not bootstrapped' do
    let(:etcd_data) { true }

    it 'refuses to re-init with a make clean hint' do
      expect(chef_run).to run_ruby_block('refuse to re-init over existing etcd data')
      expect { chef_run.ruby_block('refuse to re-init over existing etcd data').block.call }.to raise_error(RuntimeError, /make clean/)
    end
  end
end
