require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Eye::Checker::ChildrenCount" do
  it "should not restart because all is ok" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_count(:below => 5), :monitor_children => {}))

    3.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    expect(@process).not_to receive(:schedule).with(:command => :restart)

    sleep 5
  end

  it "should restart with strategy :restart" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_count(:below => 5), :monitor_children => {}))

    10.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    expect(@process.wrapped_object).to receive(:schedule).with(:command => :restart)

    sleep 5
  end

  it "should kill 5 older childs" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_count(:below => 3, :strategy => :kill_old),
      :monitor_children => {}))

    10.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    sleep 5

    @pids[0...7].each { |p| expect(Eye::System.pid_alive?(p)).to eq false }
    @pids[7..-1].each { |p| expect(Eye::System.pid_alive?(p)).to eq true }
  end

  it "should kill 5 newer childs" do
    @process = start_ok_process(C.p1.merge(:checks => C.check_children_count(:below => 3, :strategy => :kill_new),
      :monitor_children => {}))

    10.times { @pids << Eye::System.daemonize("sleep 10")[:pid] }
    allow(Eye::SystemResources).to receive(:children).with(@process.pid){ @pids }
    @process.add_children

    sleep 5

    @pids[0...3].each { |p| expect(Eye::System.pid_alive?(p)).to eq true }
    @pids[3..-1].each { |p| expect(Eye::System.pid_alive?(p)).to eq false }
  end

end
