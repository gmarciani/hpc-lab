require 'spec_helper'

describe 'hpc-lab-admin::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before { stub_file(:exist?, '/opt/hpc-lab/ssh/id_ed25519.pub', true) }

  it 'installs the dependencies, configures ssh and installs the libraries' do
    %w(dependencies ssh libraries).each { |recipe| expect(chef_run).to include_recipe("hpc-lab-admin::#{recipe}") }
  end
end
