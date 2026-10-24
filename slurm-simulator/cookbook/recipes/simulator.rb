# The UB CCR Slurm Simulator, built from source into slurm-simulator/slurm, and its
# toolkit (slurmsim) in slurm-simulator/tools. Both are installed once; a version
# change needs a new container (make redeploy).
simulator = node['hpc-lab-slurm-simulator']
sim_home = "#{simulator['home']}/slurm-simulator"
build_dir = "#{Chef::Config[:file_cache_path]}/slurm-simulator"

directory sim_home do
  recursive true
end

execute 'install the slurm simulator toolkit' do
  command "mkdir -p #{sim_home}/tools && curl -fsSL https://codeload.github.com/ubccr-slurm-simulator/slurm_sim_tools/tar.gz/refs/tags/v#{simulator['sim_tools_version']} | tar -xz -C #{sim_home}/tools --strip-components=1"
  creates "#{sim_home}/tools/bin/slurmsim"
end

# The configure options are upstream's (docker/slurm_sim/slurm_sim.Dockerfile in the toolkit):
# - --enable-simulator: the controller replays the events of a workload on a simulated clock;
# - --enable-front-end: one front end stands for every node, so no slurmd runs per node;
# - --disable-x11, --with-hdf5=no: features a simulation does not use;
# - -Wno-error=...: the simulator sources raise these warnings, which would stop the build.
execute 'build the slurm simulator' do
  command "rm -rf #{build_dir} && mkdir -p #{build_dir}/build" \
          " && curl -fsSL https://codeload.github.com/ubccr-slurm-simulator/slurm_simulator/tar.gz/#{simulator['simulator_commit']} | tar -xz -C #{build_dir} --strip-components=1" \
          " && cd #{build_dir}/build && ../configure --prefix=#{sim_home}/slurm --enable-simulator --enable-front-end --disable-x11 --with-hdf5=no" \
          " CFLAGS='-O3 -Wno-error=unused-variable -Wno-error=implicit-function-declaration'" \
          ' && make -j "$(nproc)" && make install'
  creates "#{sim_home}/slurm/sbin/slurmctld"
end
