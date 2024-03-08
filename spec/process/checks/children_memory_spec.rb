require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Eye::Checker::ChildrenMemory" do
  it "should not restart because all is ok" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_memory(:below => 50), :monitor_children => {}))

    3.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    allow(Eye::SystemResources).to receive(:memory).with(anything) { 1 }

    expect(@process).not_to receive(:schedule).with({ :command => :restart })

    sleep 5
  end

  it "should restart with strategy :restart" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_memory(:below => 50), :monitor_children => {}))

    10.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    allow(Eye::SystemResources).to receive(:memory).with(anything) { 11 }
    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

    sleep 5
  end
end
