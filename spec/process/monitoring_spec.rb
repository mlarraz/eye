require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Monitoring" do

  [C.p1, C.p2].each do |cfg|

    it "process crashed, should restart #{cfg[:name]}" do
      start_ok_process(cfg)
      old_pid = @pid

      die_process!(@pid)
      expect(@process.wrapped_object).to receive(:notify).with(:info, anything)

      sleep 7 # wait until monitor upping process

      @pid = @process.pid
      expect(@pid).not_to eq old_pid

      expect(Eye::System.pid_alive?(old_pid)).to eq false
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.states_history.states).to seq(:down, :starting, :up)
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "process crashed, should restart #{cfg[:name]} in restore_in interval" do
      start_ok_process(cfg.merge(:restore_in => 3.seconds))
      old_pid = @pid

      die_process!(@pid)
      expect(@process.wrapped_object).to receive(:notify).with(:info, anything)

      sleep 10 # wait until monitor upping process

      @pid = @process.pid
      expect(@pid).not_to eq old_pid

      expect(Eye::System.pid_alive?(old_pid)).to eq false
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.states_history.states).to seq(:down, :starting, :up)
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
      expect(@process.load_pid_from_file).to eq @process.pid
    end
  end

  it "if keep_alive disabled, process should not up" do
    start_ok_process(C.p1.merge(:keep_alive => false))
    old_pid = @process.pid

    die_process!(@pid)

    sleep 7 # wait until monitor upping process

    expect(@process.pid).to eq nil
    expect(Eye::System.pid_alive?(@pid)).to eq false

    expect(@process.state_name).to eq :unmonitored
    expect(@process.watchers.keys).to eq []
    expect(@process.states_history.states).to end_with(:up, :down, :unmonitored)
    expect(@process.load_pid_from_file).to eq nil
  end

  it "process in status unmonitored should not up automatically" do
    start_ok_process(C.p1)
    old_pid = @pid

    @process.unmonitor
    expect(@process.state_name).to eq :unmonitored

    die_process!(@pid)

    sleep 7 # wait until monitor upping process

    expect(@process.pid).to eq nil

    expect(Eye::System.pid_alive?(old_pid)).to eq false

    expect(@process.state_name).to eq :unmonitored
    expect(@process.watchers.keys).to eq []
    expect(@process.load_pid_from_file).to eq old_pid
  end

  it "EMULATE UNICORN hard understanding restart case" do
    start_ok_process(C.p2)
    old_pid = @pid

    # rewrite by another :)
    @pid = Eye::System.daemonize("ruby sample.rb", {:environment => {"ENV1" => "SECRET1"},
      :working_dir => C.p2[:working_dir], :stdout => @log})[:pid]

    File.open(C.p2[:pid_file], 'w'){|f| f.write(@pid) }

    sleep 5

    # both processes exists now
    # and in pid_file writed second pid
    expect(@process.load_pid_from_file).to eq @pid
    expect(@process.pid).to eq old_pid

    die_process!(old_pid)

    sleep 5 # wait until monitor upping process

    expect(@process.pid).to eq @pid
    expect(old_pid).not_to eq @pid
    expect(@process.load_pid_from_file).to eq @pid

    expect(Eye::System.pid_alive?(old_pid)).to eq false
    expect(Eye::System.pid_alive?(@pid)).to eq true

    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
    expect(@process.load_pid_from_file).to eq @process.pid
  end

end
