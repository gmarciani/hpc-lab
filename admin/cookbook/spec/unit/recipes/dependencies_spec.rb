require 'spec_helper'

describe 'hpc-lab-admin::dependencies' do
  let(:machine) { 'x86_64' }
  let(:installed) { false }
  let(:chef_run) { ChefSpec::SoloRunner.new { |node| node.automatic['kernel']['machine'] = machine }.converge(described_recipe) }

  before { stub_file(:exist?, '/usr/local/bin/helm', installed) }

  it 'installs the packages' do
    expect(chef_run).to install_package(%w(openssh-server openssh-clients jq openssl tar gzip))
  end

  it 'downloads kubectl and helm for the machine architecture' do
    expect(chef_run).to create_if_missing_remote_file('/usr/local/bin/kubectl')
      .with(source: ['https://dl.k8s.io/release/v1.36.4/bin/linux/amd64/kubectl'], mode: '0755')
    expect(chef_run).to run_execute('install helm')
      .with(command: %r{curl -fsSL https://get\.helm\.sh/helm-v3\.22\.0-linux-amd64\.tar\.gz \| tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm})
  end

  context 'when helm is already installed' do
    let(:installed) { true }

    it 'skips the download regardless of the version' do
      expect(chef_run).not_to run_execute('install helm')
    end
  end

  context 'on arm64' do
    let(:machine) { 'aarch64' }

    it 'downloads the arm64 binaries' do
      expect(chef_run).to create_if_missing_remote_file('/usr/local/bin/kubectl').with(source: ['https://dl.k8s.io/release/v1.36.4/bin/linux/arm64/kubectl'])
      expect(chef_run).to run_execute('install helm').with(command: /linux-arm64\.tar\.gz/)
    end
  end

  context 'on an unsupported architecture' do
    let(:machine) { 'riscv64' }

    it 'fails' do
      expect { chef_run }.to raise_error(KeyError, /riscv64/)
    end
  end
end
