require File.dirname(__FILE__) + '/../spec_helper'

describe "#update_config" do
  before :each do
    @cfg = C.p3.merge(:checks => join(C.check_mem, C.check_cpu), :monitor_children => {})
    start_ok_process(@cfg)
    sleep 6
  end

  after :each do
    @process.stop if @process
  end

  it "update only env" do
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children, :check_memory, :check_cpu]
    expect(@process.children.keys.size).to eq 3
    child_pids = @process.children.keys
    expect(@process[:environment]["PID_NAME"]).to be

    @process.update_config(@cfg.merge(:environment => @cfg[:environment].merge({"ENV2" => "SUPER"})))
    sleep 5

    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children, :check_memory, :check_cpu]
    expect(@process.children.keys.size).to eq 3
    expect(@process.children.keys).to eq child_pids
    expect(@process[:environment]["ENV2"]).to eq "SUPER"
    expect(@process.pid).to eq @pid
  end

  it "update watchers" do
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children, :check_memory, :check_cpu]
    expect(@process.children.keys.size).to eq 3
    child_pids = @process.children.keys

    @process.update_config(@cfg.merge(:checks => C.check_mem))
    sleep 5

    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children, :check_memory]
    expect(@process.children.keys.size).to eq 3
    expect(@process.children.keys).to eq child_pids
    expect(@process.pid).to eq @pid
  end

  it "when disable monitor_children they should remove" do
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children, :check_memory, :check_cpu]
    expect(@process.children.keys.size).to eq 3
    child_pids = @process.children.keys

    @process.update_config(@cfg.merge(:monitor_children => nil))
    sleep 5

    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_memory, :check_cpu]
    expect(@process.children.keys.size).to eq 0
    expect(@process.pid).to eq @pid
  end

end
