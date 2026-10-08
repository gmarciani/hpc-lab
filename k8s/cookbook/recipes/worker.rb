# Wait for the API server, then kubeadm join. The CA hash is not verified: the
# token is a secret shared on a private compose network, enough for a lab.
k8s = node['hpc-lab-k8s']
endpoint = "#{k8s['control_plane_host']}:#{k8s['api_port']}"
kubelet_conf = '/etc/kubernetes/kubelet.conf'

execute 'wait for the API server' do
  command "timeout 300 bash -c 'until curl -ksf https://#{endpoint}/healthz >/dev/null; do sleep 2; done'"
  not_if { ::File.exist?(kubelet_conf) }
end

execute 'kubeadm join' do
  command "kubeadm join #{endpoint} --token \"$K8S_TOKEN\" --discovery-token-unsafe-skip-ca-verification --skip-phases preflight"
  live_stream true
  not_if { ::File.exist?(kubelet_conf) }
end
