require File.dirname(__FILE__) + '/../spec_helper'

describe "Intergration restart" do
  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration.erb"))
    end

    expect(@processes.size).to eq 3
    expect(@processes.map(&:state_name).uniq).to eq [:up]
    @samples = @controller.all_groups.detect{|c| c.name == 'samples'}
  end

  after :each do
    stop_controller
  end

  it "restart process group samples" do
    @controller.command(:restart, "samples")
    sleep 11 # while they restarting

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).not_to eq @old_pid1
    expect(@p2.pid).not_to eq @old_pid2
    expect(@p3.pid).to eq @old_pid3
  end

  it "restart process" do
    @controller.command(:restart, "sample1")
    sleep 10 # while they restarting

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).not_to eq @old_pid1
    expect(@p2.pid).to eq @old_pid2
    expect(@p3.pid).to eq @old_pid3
  end

  it "restart process with signal" do
    should_spend(3, 0.3) do
      c = Celluloid::Condition.new
      @controller.command(:restart, "sample1", :signal => c)
      c.wait
    end

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).not_to eq @old_pid1
  end

  it "restart process forking" do
    @controller.command(:restart, "forking")
    sleep 11 # while they restarting

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).to eq @old_pid1
    expect(@p2.pid).to eq @old_pid2
    expect(@p3.pid).not_to eq @old_pid3

    expect(@p1.scheduler_last_reason).to eq 'monitor by user'
    expect(@p3.scheduler_last_reason).to eq 'restart by user'
  end

  it "restart forking named child" do
    @p3.wait_for_condition(15, 0.3) { @p3.children.size == 3 }
    @children = @p3.children.keys
    expect(@children.size).to eq 3
    dead_pid = @children.sample

    expect(@controller.command(:restart, "child-#{dead_pid}")).to eq({:result => ["int:forking:child-#{dead_pid}"]})
    sleep 11 # while it

    new_children = @p3.children.keys
    expect(new_children.size).to eq 3
    expect(new_children).not_to include(dead_pid)
    (@children - [dead_pid]).each do |pid|
      expect(new_children).to include(pid)
    end

    expect(@p3.scheduler_history.states).to include("restart_child")
  end

  it "restart missing" do
    expect(@controller.command(:restart, "blabla")).to eq({:result => []})
    sleep 1
    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).to eq @old_pid1
    expect(@p2.pid).to eq @old_pid2
    expect(@p3.pid).to eq @old_pid3
  end

end
