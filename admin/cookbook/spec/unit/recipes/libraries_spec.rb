require 'spec_helper'

describe 'hpc-lab-admin::libraries' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'copies the lab scripts whole' do
    expect(chef_run).to create_remote_directory('/usr/local/bin').with(source: 'usr/local/bin', files_mode: '0755')
  end

  it 'renders the helper library exporting the lab folder for the scripts' do
    expect(chef_run).to render_file('/usr/local/lib/hpc-lab.sh').with_content(%r{^export HPC_LAB_HOME=/opt/hpc-lab$})
  end
end
