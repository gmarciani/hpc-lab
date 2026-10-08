# kubeadm init, bootstrap token, CNI, storage class and the kubeconfig for admin.
k8s = node['hpc-lab-k8s']
kubelet_conf = '/etc/kubernetes/kubelet.conf'
admin_conf = { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }

ruby_block 'refuse to re-init over existing etcd data' do
  block { raise 'etcd data exists but /etc/kubernetes is empty; re-initialising would corrupt the cluster. Run: make clean' }
  only_if { ::File.directory?('/var/lib/etcd/member') && !::File.exist?(kubelet_conf) }
end

execute 'kubeadm init' do
  command 'kubeadm init --config /etc/kubeadm.conf --skip-token-print'
  live_stream true
  not_if { ::File.exist?(kubelet_conf) }
end

# K8S_TOKEN comes from the unit's EnvironmentFile; the guard runs in the same environment.
execute 'kubeadm token create' do
  command 'kubeadm token create "$K8S_TOKEN" --ttl 0'
  environment admin_conf
  not_if 'kubeadm token list | grep -qF "$K8S_TOKEN"'
end

# kind's bundled CNI manifest carries a Go template placeholder for the pod subnet.
execute 'kubectl apply cni' do
  command "sed 's|{{ .PodSubnet }}|#{k8s['pod_subnet']}|g' /kind/manifests/default-cni.yaml | kubectl apply -f -"
  environment admin_conf
  not_if 'kubectl -n kube-system get daemonset kindnet'
end

execute 'kubectl apply storage' do
  command 'kubectl apply -f /kind/manifests/default-storage.yaml'
  environment admin_conf
  not_if 'kubectl get storageclass standard'
end

# Read by the admin container through the compose volume `kubeconfig`.
file '/output/config' do
  content lazy { ::File.read('/etc/kubernetes/admin.conf') }
  mode '0644'
  sensitive true
end
