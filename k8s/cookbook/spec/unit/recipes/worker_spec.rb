require 'spec_helper'

describe 'hpc-lab-k8s::worker' do
  let(:bootstrapped) { false }
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before { stub_file(:exist?, '/etc/kubernetes/kubelet.conf', bootstrapped) }

  it 'waits for the API server, then joins with the token from the environment' do
    expect(chef_run).to run_execute('wait for the API server')
      .with(command: %r{timeout 300 bash -c 'until curl -ksf https://k8s-control-plane:6443/healthz})
    expect(chef_run).to run_execute('kubeadm join')
      .with(command: 'kubeadm join k8s-control-plane:6443 --token "$K8S_TOKEN" --discovery-token-unsafe-skip-ca-verification --skip-phases preflight')
  end

  context 'when the node is already bootstrapped' do
    let(:bootstrapped) { true }

    it 'skips the wait and the join' do
      expect(chef_run).not_to run_execute('wait for the API server')
      expect(chef_run).not_to run_execute('kubeadm join')
    end
  end
end
