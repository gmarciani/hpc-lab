# The lab scripts and the library they source, which exports the lab folder
# from the `home` attribute as HPC_LAB_HOME.
remote_directory '/usr/local/bin' do
  source 'usr/local/bin'
  files_mode '0755'
end

template '/usr/local/lib/hpc-lab.sh' do
  source 'usr/local/lib/hpc-lab.sh.erb'
  variables(hpc_lab_home: node['hpc-lab-admin']['home'])
end
