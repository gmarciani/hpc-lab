# Remove the Slurm cluster; the operator, cert-manager and the volumes stay.
pods = 'kubectl -n slurm get pods -l "app.kubernetes.io/name in (slurmctld,slurmrestd,slurmd,login)" --no-headers 2>/dev/null'

execute 'helm uninstall slurm' do
  command 'helm -n slurm uninstall slurm --wait --timeout 10m || { kubectl -n slurm get pods >&2; exit 1; }'
  live_stream true
  only_if 'helm -n slurm status slurm'
end

# The operator deletes the pods of its custom resources asynchronously.
execute 'wait for the Slurm pods to be gone' do
  command "timeout 600 bash -c 'while [ -n \"$(#{pods})\" ]; do sleep 5; done' || { kubectl -n slurm get pods >&2; exit 1; }"
  only_if "#{pods} | grep -q ."
end
