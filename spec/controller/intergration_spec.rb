require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Intergration" do
  before :each do
    start_controller do
      res = @controller.load_erb(fixture("dsl/integration.erb"))
      expect(Marshal.dump(res)).not_to include("ActiveSupport")
    end

    expect(@processes.size).to eq 3
    expect(@processes.map(&:state_name).uniq).to eq [:up]

    @samples = @controller.all_groups.detect{|c| c.name == 'samples'}
  end

  after :each do
    stop_controller
  end

  it "should be ok status string" do
    str = Eye::Cli.new.send(:render_info, @controller.info_data)
    s = str.split("\n").size
    expect(s).to be >= 6
    expect(s).to be <= 8
    expect(str.strip.size).to be > 100
  end

  it "stop group" do
    @controller.command(:stop, "samples")
    sleep 7 # while they stopping

    expect(@p1.state_name).to eq :unmonitored
    expect(@p2.state_name).to eq :unmonitored
    expect(@p3.state_name).to eq :up

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq false
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    sth = @p1.states_history.last
    expect(sth[:reason].to_s).to eq 'stop by user'
    expect(sth[:state]).to eq :unmonitored
  end

  it "stop process" do
    @controller.command(:stop, "sample1")
    sleep 7 # while they stopping

    expect(@p1.state_name).to eq :unmonitored
    expect(@p2.state_name).to eq :up
    expect(@p3.state_name).to eq :up

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true
  end

  it "unmonitor process" do
    expect(@controller.command(:unmonitor, "sample1")).to eq({:result => ["int:samples:sample1"]})
    sleep 7 # while they stopping

    expect(@p1.state_name).to eq :unmonitored
    expect(@p2.state_name).to eq :up
    expect(@p3.state_name).to eq :up

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true
  end

  it "send signal to process throught all schedules" do
    expect(@p1).to receive(:signal).with('usr2')
    expect(@p2).to receive(:signal).with('usr2')
    expect(@p3).to receive(:signal).with('usr2')

    expect(@controller.command(:signal, 'usr2', "int")).to eq({:result => ["int"]})
    sleep 3 # while they gettings

    expect(@p1.scheduler_last_command).to eq :signal
    expect(@p1.scheduler_last_reason).to eq 'signal by user'

    expect(@p1).to receive(:signal).with('usr1')
    @controller.command(:signal, 'usr1', 'sample1')
    sleep 0.5
  end

  it "stop_all" do
    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@pids.map { |p| Eye::System.pid_alive?(p) }.uniq).to eq [true]

    should_spend(4, 3.5) do
      @controller.command(:stop_all)
      @controller.command(:restart, 'all') # should not be affected
    end

    expect(@processes.map(&:state_name).uniq).to eq [:unmonitored]
    expect(@pids.map { |p| Eye::System.pid_alive?(p) }.uniq).to eq [false]
  end

end
