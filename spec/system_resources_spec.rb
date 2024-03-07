require File.dirname(__FILE__) + '/spec_helper'

describe "Eye::SystemResources" do
  before :each do
    Eye::SystemResources.cache.clear
  end

  it "should get memory" do
    x = Eye::SystemResources.memory($$)
    expect(x).to be > 20.megabytes
    expect(x).to be < 300.megabytes
  end

  it "should get cpu" do
    x = Eye::SystemResources.cpu($$)
    expect(x).to be >= 0
    expect(x).to be <= 100
  end

  it "should get cputime" do
    x = Eye::SystemResources.cputime($$)
    expect(x).to be >= 0
    expect(x).to be <= 30 * 60
  end

  it "when unknown pid" do
    pid = 12342341
    expect(Eye::SystemResources.cpu(pid)).to eq nil
    expect(Eye::SystemResources.memory(pid)).to eq nil
    expect(Eye::SystemResources.children(pid)).to eq []

    pid = nil
    expect(Eye::SystemResources.cpu(pid)).to eq nil
    expect(Eye::SystemResources.memory(pid)).to eq nil
    expect(Eye::SystemResources.start_time(pid)).to eq nil
    expect(Eye::SystemResources.children(pid)).to eq []
  end

  it "should get start time" do
    x = Eye::SystemResources.start_time($$)
    expect(x).to be >= 1000000000
    expect(x).to be <= 2000000000
  end

  it "should get children" do
    @pid = fork { at_exit{}; sleep 3; exit }
    Process.detach(@pid)
    sleep 0.5
    x = Eye::SystemResources.children($$)
    expect(x.class).to eq Array
    expect(x).to include(@pid)
  end

  describe "leaf_child" do
    it "should get leaf_child" do
      @pid = fork { at_exit{}; sleep 3; exit }
      Process.detach(@pid)
      sleep 0.5
      x = Eye::SystemResources.leaf_child($$)
      expect(x).to eq @pid
    end

    it "complex leaf_child" do
      pid = Process.spawn(*Shellwords.shellwords('sh -c "sleep 10 | logger"'))
      x = Eye::SystemResources.leaf_child($$)
      args = Eye::SystemResources.args(x)
      expect(args).to_not include('sh')
      expect(args).to_not include('logger')
      expect(args).to start_with('sleep')
    end

    it "super complex leaf_child" do
      str = "/bin/sh #{C.sample_dir}/leaf_child.sh | logger"
      pid = Process.spawn(*Shellwords.shellwords('sh -c "' + str + '"'))
      Process.detach(pid)
      sleep 0.5
      x = Eye::SystemResources.leaf_child($$)
      args = Eye::SystemResources.args(x)
      expect(args).to eq 'sleep 15'
    end
  end

  it "should cache and update when interval" do
    Eye::SystemResources.cache.setup_expire(1)

    allow(Eye::Sigar).to receive(:proc_mem) { OpenStruct.new(:resident => 1240000) }

    x1 = Eye::SystemResources.memory($$)
    x2 = Eye::SystemResources.memory($$)
    expect(x1).to eq x2

    allow(Eye::Sigar).to receive(:proc_mem) { OpenStruct.new(:resident => 1230000) }

    sleep 0.5
    x3 = Eye::SystemResources.memory($$)
    expect(x1).to eq x3

    sleep 0.8
    x4 = Eye::SystemResources.memory($$)
    expect(x1).to_not eq x4 # first value is new
  end
end
