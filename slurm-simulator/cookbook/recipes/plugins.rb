# Custom scheduling policies: every slurm-simulator/plugins/<type>_<name>.c, mounted
# from the host, is built into the simulator as the Slurm plugin <type>/<name>, which a
# slurm_conf attribute selects (PriorityType=priority/sjf for priority_sjf.c).
# slurm-simulate converges this recipe first, so an edited plugin is rebuilt for the
# next simulation: whenever its source is newer than the built plugin.
sim_home = "#{node['hpc-lab-slurm-simulator']['home']}/slurm-simulator"
# Slurm loads plugins from the lib/slurm folder of its installation (PluginDir).
plugin_dir = "#{sim_home}/slurm/lib/slurm"
# The simulator sources and build (recipe simulator): a plugin compiles against
# their headers and config.h, which the build generated (SLURM_SIMULATOR among them).
build_dir = "#{Chef::Config[:file_cache_path]}/slurm-simulator"

Dir.glob("#{sim_home}/plugins/*.c").sort.each do |source|
  library = "#{plugin_dir}/#{::File.basename(source, '.c')}.so"

  execute "build plugin #{::File.basename(source)}" do
    command "gcc -shared -fPIC -O2 -Wall -DHAVE_CONFIG_H -I#{build_dir} -I#{build_dir}/build -o #{library} #{source}"
    not_if { ::File.exist?(library) && ::File.mtime(library) >= ::File.mtime(source) }
  end
end
