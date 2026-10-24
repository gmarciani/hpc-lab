require 'spec_helper'

describe 'hpc-lab-slurm-simulator::database' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'configures MariaDB to create the slurmdbd user at start' do
    expect(chef_run).to create_remote_directory('/etc/mysql').with(source: 'etc/mysql')
  end

  it 'creates the server socket folder for the mysql user' do
    expect(chef_run).to create_directory('/run/mysqld').with(owner: 'mysql', group: 'mysql')
  end
end
