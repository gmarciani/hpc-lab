# Packages: the toolchain and MariaDB client headers the simulator build needs,
# the MariaDB server, the Python modules of the toolkit, column for the results,
# procps (ps, pkill), which the toolkit and slurm-simulate use on the daemons, and
# matplotlib, which slurm-simulate-report plots with.
# The base image ships no package lists; :periodic refreshes them at most once a day.
apt_update 'package lists' do
  action :periodic
end

package %w(build-essential libmariadb-dev mariadb-server python3 python3-pandas python3-psutil python3-pymysql python3-tqdm bsdextrautils procps python3-matplotlib)
