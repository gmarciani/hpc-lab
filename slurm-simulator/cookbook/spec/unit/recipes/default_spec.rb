require 'spec_helper'

describe 'hpc-lab-slurm-simulator::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'installs the dependencies, builds the simulator and the plugins, configures the database and renders the simulation' do
    %w(dependencies simulator plugins database simulation).each { |recipe| expect(chef_run).to include_recipe("hpc-lab-slurm-simulator::#{recipe}") }
  end
end
