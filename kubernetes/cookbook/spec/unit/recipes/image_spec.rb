require 'spec_helper'

describe 'hpc-lab-kubernetes::image' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'installs the first-boot unit converging this cookbook from the lab folder' do
    expect(chef_run).to render_file('/etc/systemd/system/kubernetes-bootstrap.service')
      .with_content(%r{^ExecStart=/usr/bin/cinc-client -c /opt/hpc-lab/chef/client\.rb -o recipe\[hpc-lab-kubernetes\]$})
      .with_content(%r{^ConditionPathExists=!/etc/kubernetes/kubelet\.conf$})
      .with_content(%r{^EnvironmentFile=/opt/hpc-lab/kubernetes\.secrets\.env$})
  end

  it 'enables the unit without a daemon-reload' do
    expect(chef_run).to enable_systemd_unit('kubernetes-bootstrap.service').with(triggers_reload: false)
  end
end
