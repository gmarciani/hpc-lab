require 'spec_helper'

describe 'hpc-lab-slurm-simulator::dependencies' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'refreshes the package lists at most once a day' do
    expect(chef_run).to periodic_apt_update('package lists')
  end

  it 'installs the build toolchain, MariaDB and the toolkit modules' do
    expect(chef_run).to install_package(%w(build-essential libmariadb-dev mariadb-server python3 python3-pandas python3-psutil python3-pymysql python3-tqdm bsdextrautils procps python3-matplotlib))
  end
end
