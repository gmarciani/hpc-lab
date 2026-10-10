require 'spec_helper'

describe 'hpc-lab-admin::ssh' do
  let(:key) { '/opt/hpc-lab/ssh/id_ed25519.pub' }
  let(:key_present) { true }
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before do
    stub_file(:exist?, key, key_present)
    stub_file(:read, key, "ssh-ed25519 AAAA hpc-lab\n")
  end

  it 'copies the sshd drop-ins and generates the host keys' do
    expect(chef_run).to create_remote_directory('/etc/ssh/sshd_config.d').with(source: 'etc/ssh/sshd_config.d')
    expect(chef_run).to run_execute('ssh-keygen -A').with(creates: '/etc/ssh/ssh_host_ed25519_key')
  end

  it 'installs the lab public key as the root authorized key' do
    expect(chef_run).to create_directory('/root/.ssh').with(mode: '0700')
    expect(chef_run).to create_file('/root/.ssh/authorized_keys').with(mode: '0600', content: "ssh-ed25519 AAAA hpc-lab\n")
  end

  context 'without the lab public key' do
    let(:key_present) { false }

    it 'fails naming the key and how to generate it' do
      expect { chef_run }.to raise_error(RuntimeError, %r{/opt/hpc-lab/ssh/id_ed25519\.pub not found.*make ssh-key})
    end
  end
end
