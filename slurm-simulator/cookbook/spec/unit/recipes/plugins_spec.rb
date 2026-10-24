require 'spec_helper'

describe 'hpc-lab-slurm-simulator::plugins' do
  let(:source) { '/opt/hpc-lab/slurm-simulator/plugins/priority_sjf.c' }
  let(:library) { '/opt/hpc-lab/slurm-simulator/slurm/lib/slurm/priority_sjf.so' }
  let(:sources) { [source] }
  let(:built) { false }
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  before do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('/opt/hpc-lab/slurm-simulator/plugins/*.c').and_return(sources)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(library).and_return(built)
    allow(File).to receive(:mtime).and_call_original
    allow(File).to receive(:mtime).with(source).and_return(Time.at(100))
    allow(File).to receive(:mtime).with(library).and_return(Time.at(200))
  end

  it 'builds each plugin source into the plugin folder of the simulator, against its build' do
    expect(chef_run).to run_execute('build plugin priority_sjf.c').with(
      command: %r{\Agcc -shared -fPIC -O2 -Wall -DHAVE_CONFIG_H -I(\S+)/slurm-simulator -I\1/slurm-simulator/build -o #{library} #{source}\z}
    )
  end

  context 'when the plugin is built from the current source' do
    let(:built) { true }

    it 'skips it' do
      expect(chef_run).not_to run_execute('build plugin priority_sjf.c')
    end
  end

  context 'without plugin sources' do
    let(:sources) { [] }

    it 'builds nothing' do
      expect(chef_run.find_resources(:execute)).to be_empty
    end
  end
end
