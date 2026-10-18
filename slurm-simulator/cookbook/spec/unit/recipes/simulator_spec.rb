require 'spec_helper'

describe 'hpc-lab-slurm-simulator::simulator' do
  let(:attrs) { {} }
  let(:chef_run) do
    ChefSpec::SoloRunner.new { |node| attrs.each { |key, value| node.normal['hpc-lab-slurm-simulator'][key] = value } }.converge(described_recipe)
  end

  it 'installs the toolkit release once' do
    expect(chef_run).to run_execute('install the slurm simulator toolkit').with(
      command: %r{curl -fsSL https://codeload\.github\.com/ubccr-slurm-simulator/slurm_sim_tools/tar\.gz/refs/tags/v3\.0 \| tar -xz -C /opt/hpc-lab/slurm-simulator/tools },
      creates: '/opt/hpc-lab/slurm-simulator/tools/bin/slurmsim'
    )
  end

  it 'builds the simulator commit in simulator mode once' do
    expect(chef_run).to run_execute('build the slurm simulator').with(
      command: %r{slurm_simulator/tar\.gz/f99a71eb2073266bba3869aa2a0ccd51c58c9bb7 .* ../configure --prefix=/opt/hpc-lab/slurm-simulator/slurm --enable-simulator --enable-front-end .* && make install$},
      creates: '/opt/hpc-lab/slurm-simulator/slurm/sbin/slurmctld'
    )
  end

  context 'with other versions' do
    let(:attrs) { { 'sim_tools_version' => '3.1', 'simulator_commit' => 'abc123' } }

    it 'downloads them' do
      expect(chef_run).to run_execute('install the slurm simulator toolkit').with(command: %r{tar\.gz/refs/tags/v3\.1 })
      expect(chef_run).to run_execute('build the slurm simulator').with(command: %r{slurm_simulator/tar\.gz/abc123 })
    end
  end
end
