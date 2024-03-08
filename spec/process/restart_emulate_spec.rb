require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Restart, emulate some real hard cases" do
  [C.p1, C.p2].each do |cfg|
    it "emulate restart as stop,start where stop command does not kill" do
      # should send command, than wait grace time,
      # and than even if old process doesnot die, start another one, (looks like bug, but this is not, it just bad using, commands)

      # same situation, when stop command kills so long time, that process cant stop
      start_ok_process(cfg.merge(:stop_command => "kill -USR1 {PID}"))
      old_pid = @pid

      expect(@process.wrapped_object).not_to receive(:check_crash)
      @process.restart

      sleep 3
      expect(@process.pid).not_to eq old_pid

      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      expect(@process.load_pid_from_file).to eq @process.pid
      expect(@process.states_history.states).to end_with(:up, :restarting, :stopping, :unmonitored, :starting, :up)

      expect(File.read(@log)).to include("USR1")
    end

    it "Bad restart command, invalid" do
      start_ok_process(cfg.merge(:restart_command => "asdfasdf sdf asd fasdf asdf"))

      expect(@process.wrapped_object).not_to receive(:check_crash)

      @process.restart
      expect(Eye::System.pid_alive?(@pid)).to eq true
      expect(@process.states_history.states).to seq(:up, :restarting, :up)
    end

    it "restart command timeouted" do
      start_ok_process(cfg.merge(:restart_command => "sleep 5", :restart_timeout => 3))
      @process.restart

      sleep 1
      expect(@process.pid).to eq @pid

      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      expect(@process.load_pid_from_file).to eq @process.pid
      expect(@process.states_history.states).to end_with(:up, :restarting, :up)
    end
  end

  it "restart eye-daemonized lock-process from unmonitored status, and process really running (WAS a problem)" do
    start_ok_process(C.p4)
    @pid = @process.pid
    @process.unmonitor
    expect(Eye::System.pid_alive?(@pid)).to eq true

    @process.restart
    expect(@process.state_name).to eq :up

    expect(Eye::System.pid_alive?(@pid)).to eq false
    expect(@process.load_pid_from_file).not_to eq @pid
  end
end
