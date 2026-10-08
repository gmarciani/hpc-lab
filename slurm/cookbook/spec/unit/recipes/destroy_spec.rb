require 'spec_helper'

describe 'hpc-lab-slurm::destroy' do
  let(:release_exists) { true }
  let(:pods_present) { true }
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before do
    stub_command('helm -n slurm status slurm').and_return(release_exists)
    stub_command(/kubectl -n slurm get pods/).and_return(pods_present)
  end

  it 'uninstalls the slurm release and waits for its pods to be gone' do
    expect(chef_run).to run_execute('helm uninstall slurm').with(command: /^helm -n slurm uninstall slurm --wait --timeout 10m/)
    expect(chef_run).to run_execute('wait for the Slurm pods to be gone').with(command: /timeout 600 bash -c 'while \[ -n "\$\(kubectl -n slurm get pods/)
  end

  context 'when the release is gone but its pods are still terminating' do
    let(:release_exists) { false }

    it 'only waits for the pods' do
      expect(chef_run).not_to run_execute('helm uninstall slurm')
      expect(chef_run).to run_execute('wait for the Slurm pods to be gone')
    end
  end

  context 'when the release and its pods are already gone' do
    let(:release_exists) { false }
    let(:pods_present) { false }

    it 'runs nothing' do
      expect(chef_run).not_to run_execute('helm uninstall slurm')
      expect(chef_run).not_to run_execute('wait for the Slurm pods to be gone')
    end
  end
end
