require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Stop" do

  describe "clear_pid_file" do
    it "stop should clear pid by default for daemonize" do
      start_ok_process(C.p1)

      @process.stop_process

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(@process.state_name).to eq :down

      expect(@process.load_pid_from_file).to eq nil
    end

    it "stop should clear pid by default for not daemonize" do
      start_ok_process(C.p2)

      @process.stop_process

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(@process.state_name).to eq :down

      expect(@process.load_pid_from_file).to eq nil
    end

    it "for not daemonize, but option enabled by manual" do
      start_ok_process(C.p2.merge(:clear_pid => false))

      @process.stop_process

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(@process.state_name).to eq :down

      expect(@process.load_pid_from_file).to eq @pid
    end
  end

  it "stop process by default command" do
    start_ok_process

    expect(@process.wrapped_object).not_to receive(:check_crash)
    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq false
    expect(@process.pid).to eq @pid
    expect(@process.state_name).to eq :down
    expect(@process.states_history.states).to end_with(:up, :stopping, :down)
    expect(@process.watchers.keys).to eq []
    expect(@process.load_pid_from_file).to eq nil
  end

  it "stop process by default command, and its not die by TERM, should stop anyway" do
    start_ok_process(C.p2.merge(:start_command => C.p2[:start_command] + " -T"))
    expect(Eye::System.pid_alive?(@pid)).to eq true

    expect(@process.wrapped_object).not_to receive(:check_crash)
    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq false
    expect(@process.pid).to eq @pid
    expect(@process.state_name).to eq :down
    expect(@process.states_history.states).to end_with(:up, :stopping, :down)
    expect(@process.watchers.keys).to eq []
    expect(@process.load_pid_from_file).to eq nil
  end

  it "stop process by specific command" do
    start_ok_process(C.p1.merge(:stop_command => "kill -9 {PID}"))

    expect(@process.wrapped_object).not_to receive(:check_crash)
    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq false
    expect(@process.state_name).to eq :down
    expect(@process.load_pid_from_file).to eq nil
  end

  it "bad command" do
    start_ok_process(C.p1.merge(:stop_command => "kill -0 {PID}"))

    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq true
    expect(@process.state_name).to eq :unmonitored # cant stop with this command, so :unmonitored

    expect(@process.load_pid_from_file).to eq @pid # needs
  end

  it "bad command timeouted" do
    start_ok_process(C.p1.merge(:stop_command => "sleep 2", :stop_timeout => 1))

    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq true
    expect(@process.state_name).to eq :unmonitored # cant stop with this command, so :unmonitored

    expect(@process.load_pid_from_file).to eq @pid # needs
  end

  it "watch_file" do
    wf = File.join(C.p1[:working_dir], %w{1111.stop})
    start_ok_process(C.p1.merge(:stop_command => "touch #{wf}",
      :start_command => C.p1[:start_command] + " -w #{wf}"))

    @process.stop_process

    expect(Eye::System.pid_alive?(@pid)).to eq false
    expect(@process.state_name).to eq :down

    expect(File.exist?(wf)).to eq false

    data = File.read(@log)
    expect(data).to include("watch file finded")

    expect(@process.load_pid_from_file).to eq nil
  end

  it "stop process by stop_signals" do
    start_ok_process(C.p1.merge(:stop_signals => [9, 2.seconds]))

    @process.schedule :stop_process
    sleep 1
    expect(Eye::System.pid_alive?(@pid)).to eq false

    expect(@process.load_pid_from_file).to eq nil
  end

  it "stop process by stop_signals" do
    start_ok_process(C.p1.merge(:stop_signals => ['usr1', 3.seconds, :TERM, 2.seconds]))

    @process.schedule :stop_process
    sleep 1.5

    # not blocking actor
    should_spend(0) do
      expect(@process.name).to eq 'blocking process'
    end

    expect(Eye::System.pid_alive?(@pid)).to eq true
    sleep 1.3
    expect(Eye::System.pid_alive?(@pid)).to eq true
    sleep 1
    expect(Eye::System.pid_alive?(@pid)).to eq false

    # should capture log
    data = File.read(@log)
    expect(data).to include("USR1 signal")
  end

  it "long stop" do
    start_ok_process(C.p3)
    pid = @process.pid

    @process.stop_process
    expect(@process.state_name).to eq :down

    expect(Eye::System.pid_alive?(pid)).to eq false

    expect(@process.load_pid_from_file).to eq nil
  end

  # it "stop process by stop_signals and commands"

  [:unmonitored, :down, :starting, :stopping].each do |st|
    it "no stop from #{st}" do
      @process = process(C.p1)
      @process.state = st.to_s # force set state

      expect(@process.wrapped_object).not_to receive(:kill_process)

      @process.stop_process
      expect(@process.state_name).to eq st
    end
  end

end
