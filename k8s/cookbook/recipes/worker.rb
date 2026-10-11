# Wait for the API server, then kubeadm join. The CA hash is not verified: the
# token is a secret shared on a private compose network, enough for a lab.
require 'resolv'

k8s = node['hpc-lab-k8s']
endpoint = "#{k8s['control_plane_host']}:#{k8s['api_port']}"
kubelet_conf = '/etc/kubernetes/kubelet.conf'

execute 'wait for the API server' do
  command "timeout 300 bash -c 'until curl -ksf https://#{endpoint}/healthz >/dev/null; do sleep 2; done'"
  not_if { ::File.exist?(kubelet_conf) }
end

# The workers are replicas of one compose service, so their hostname is the
# container id, which changes when the container is recreated. The node is named
# after the replica instead: Docker's DNS maps the container IP to the container
# name, <project>-k8s-worker-<index>.<network>, and the node becomes k8s-worker-<index>.
# kubeadm saves the name for kubelet (--hostname-override in /var/lib/kubelet).
execute 'kubeadm join' do
  command lazy {
    container = Resolv::DNS.new.getname(node['ipaddress']).to_s
    node_name = container.split('.').first.delete_prefix("#{k8s['compose_project']}-")
    "kubeadm join #{endpoint} --token \"$K8S_TOKEN\" --node-name #{node_name} --discovery-token-unsafe-skip-ca-verification --skip-phases preflight"
  }
  live_stream true
  not_if { ::File.exist?(kubelet_conf) }
end
