# Packages, kubectl and helm.
admin = node['hpc-lab-admin']
arch = { 'x86_64' => 'amd64', 'aarch64' => 'arm64' }.fetch(node['kernel']['machine'])

package %w(openssh-server openssh-clients jq openssl tar gzip)

# Both are installed once; a version change needs a new container (make redeploy).
remote_file '/usr/local/bin/kubectl' do
  source "https://dl.k8s.io/release/v#{admin['kubectl_version']}/bin/linux/#{arch}/kubectl"
  mode '0755'
  action :create_if_missing
end

execute 'install helm' do
  command "curl -fsSL https://get.helm.sh/helm-v#{admin['helm_version']}-linux-#{arch}.tar.gz | tar -xz -C /usr/local/bin --strip-components=1 linux-#{arch}/helm"
  not_if { ::File.exist?('/usr/local/bin/helm') }
end
