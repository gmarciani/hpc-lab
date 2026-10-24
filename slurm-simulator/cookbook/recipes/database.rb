# MariaDB, the accounting database of the simulated cluster: slurmdbd stores the
# simulated jobs there, and the toolkit reads them back (sacct) into the results.
# The entrypoint runs the server once the converge is done.
remote_directory '/etc/mysql' do
  source 'etc/mysql'
end

# Folder of the server socket and pid file; the package creates it through
# systemd-tmpfiles, which does not run in the container.
directory '/run/mysqld' do
  owner 'mysql'
  group 'mysql'
end
