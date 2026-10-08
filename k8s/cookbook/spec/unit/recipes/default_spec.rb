require 'spec_helper'

describe 'hpc-lab-k8s::default' do
  let(:token) { 'abcdef.0123456789abcdef' }
  let(:hostname) { 'k8s-control-plane' }
  let(:chef_run) { ChefSpec::SoloRunner.new { |node| node.automatic['hostname'] = hostname }.converge(described_recipe) }

  around do |example|
    previous = ENV.fetch('K8S_TOKEN', nil)
    ENV['K8S_TOKEN'] = token
    example.run
    ENV['K8S_TOKEN'] = previous
  end

  before do
    stub_command(/kubeadm token list|kubectl/).and_return(false)
    stub_file(:exist?, '/etc/kubernetes/kubelet.conf', false)
  end

  it 'checks the bundled kubeadm against the kubernetes_version attribute' do
    expect(chef_run).to run_execute('kubeadm is v1.36.4').with(command: "kubeadm version -o short | grep -qxF 'v1.36.4'")
  end

  it 'renders kubeadm.conf from the attributes' do
    expect(chef_run).to render_file('/etc/kubeadm.conf')
      .with_content(/^kubernetesVersion: v1\.36\.4$/)
      .with_content(/^clusterName: hpc-lab$/)
      .with_content(/^controlPlaneEndpoint: "k8s-control-plane:6443"$/)
      .with_content(/^  certSANs: \[localhost, "127\.0\.0\.1", "k8s-control-plane"\]$/)
      .with_content(%r{podSubnet: "10\.244\.0\.0/16"})
      .with_content(%r{serviceSubnet: "10\.96\.0\.0/16"})
  end

  it 'configures kubeadm, kubelet and kube-proxy for a node running in a container' do
    expect(chef_run).to render_file('/etc/kubeadm.conf')
      .with_content(/^skipPhases:\n  - preflight$/)
      .with_content(/^cgroupDriver: systemd$/)
      .with_content(%r{^cgroupRoot: /kubelet$})
      .with_content(/^failSwapOn: false$/)
      .with_content(/^imageGCHighThresholdPercent: 100$/)
      .with_content(/^  nodefs\.available: "0%"\n  nodefs\.inodesFree: "0%"\n  imagefs\.available: "0%"$/)
      .with_content(/^  maxPerCore: 0$/)
  end

  it 'creates the shared directory with the sticky bit' do
    expect(chef_run).to create_directory('/shared').with(mode: '1777')
  end

  it 'initialises the cluster on the control-plane host' do
    expect(chef_run).to include_recipe('hpc-lab-k8s::control_plane')
    expect(chef_run).not_to include_recipe('hpc-lab-k8s::worker')
  end

  context 'on a worker host' do
    let(:hostname) { 'k8s-worker-1' }

    it 'joins the cluster' do
      expect(chef_run).to include_recipe('hpc-lab-k8s::worker')
      expect(chef_run).not_to include_recipe('hpc-lab-k8s::control_plane')
    end
  end

  context 'without K8S_TOKEN' do
    let(:token) { '' }

    it 'fails before converging any resource' do
      expect { chef_run }.to raise_error(RuntimeError, /K8S_TOKEN is not set/)
    end
  end
end
