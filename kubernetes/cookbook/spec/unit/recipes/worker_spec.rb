require 'spec_helper'

describe 'hpc-lab-kubernetes::worker' do
  let(:bootstrapped) { false }
  let(:chef_run) { ChefSpec::SoloRunner.new { |node| node.automatic['ipaddress'] = '172.18.0.5' }.converge(described_recipe) }

  before do
    stub_file(:exist?, '/etc/kubernetes/kubelet.conf', bootstrapped)
    # Docker's DNS names the container IP after the compose replica.
    dns = instance_double(Resolv::DNS)
    allow(dns).to receive(:getname).with('172.18.0.5').and_return(Resolv::DNS::Name.create('hpc-lab-kubernetes-worker-3.hpc-lab_default'))
    allow(Resolv::DNS).to receive(:new).and_return(dns)
  end

  it 'waits for the API server, then joins with the token from the environment' do
    expect(chef_run).to run_execute('wait for the API server')
      .with(command: %r{timeout 300 bash -c 'until curl -ksf https://kubernetes-control-plane:6443/healthz})
    expect(chef_run).to run_execute('kubeadm join')
      .with(command: /^kubeadm join kubernetes-control-plane:6443 --token "\$KUBERNETES_TOKEN" .*--discovery-token-unsafe-skip-ca-verification --skip-phases preflight$/)
  end

  it 'names the node after its compose replica, not the container id' do
    expect(chef_run).to run_execute('kubeadm join').with(command: / --node-name kubernetes-worker-3 /)
  end

  context 'when the node is already bootstrapped' do
    let(:bootstrapped) { true }

    it 'skips the wait and the join' do
      expect(chef_run).not_to run_execute('wait for the API server')
      expect(chef_run).not_to run_execute('kubeadm join')
    end
  end
end
