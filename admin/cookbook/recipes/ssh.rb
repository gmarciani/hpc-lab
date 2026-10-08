# sshd configuration, host keys and the lab public key, generated per machine
# by the Makefile and mounted from admin/ssh, as the root authorized key.
key = "#{node['hpc-lab-admin']['home']}/ssh/id_ed25519.pub"
raise "#{key} not found: `make ssh-key` generates it and docker-compose.yaml mounts admin/ssh" unless ::File.exist?(key)

remote_directory '/etc/ssh/sshd_config.d' do
  source 'etc/ssh/sshd_config.d'
end

execute 'ssh-keygen -A' do
  creates '/etc/ssh/ssh_host_ed25519_key'
end

directory '/root/.ssh' do
  mode '0700'
end

file '/root/.ssh/authorized_keys' do
  content lazy { ::File.read(key) }
  mode '0600'
end
