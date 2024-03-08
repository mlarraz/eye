require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Restart" do
  [C.p1, C.p2].each do |cfg|
    it "restart by default command #{cfg[:name]}" do
      start_ok_process(cfg)
      old_pid = @pid

      expect(@process).not_to receive(:check_crash)
      @process.restart

      expect(@process.pid).not_to eq old_pid
      expect(@process.pid).to be > 0

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(Eye::System.pid_alive?(@process.pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.states_history.states).to seq(:up, :restarting, :stopping, :down, :starting, :up)
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "stop_command is #{cfg[:name]}" do
      start_ok_process(cfg.merge(:stop_command => "kill -9 {PID}"))
      old_pid = @pid

      expect(@process).not_to receive(:check_crash)
      @process.restart

      expect(@process.pid).not_to eq old_pid
      expect(@process.pid).to be > 0

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(Eye::System.pid_alive?(@process.pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "restart_command is, and not kill (USR1)" do
      # not trully test, but its ok as should send signal (unicorn case)
      start_ok_process(cfg.merge(:restart_command => "kill -USR1 {PID}"))
      old_pid = @pid

      expect(@process).not_to receive(:check_crash)
      @process.restart

      sleep 3
      expect(@process.pid).to eq old_pid

      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      expect(@process.load_pid_from_file).to eq @process.pid
      expect(@process.states_history.states).to end_with(:up, :restarting, :up)

      expect(File.read(@log)).to include("USR1")
    end

    it "restart_command is #{cfg[:name]} and kills" do
      # not really restartin, just killing
      # so monitor should see that process died, and up it
      start_ok_process(cfg.merge(:restart_command => "kill -9 {PID}"))

      expect(@process).to receive(:check_crash)

      @process.restart
      sleep 0.5
      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(@process.states_history.states).to seq(:up, :restarting, :down)
    end
  end

  [:down, :unmonitored, :up].each do |st|
    it "ok restart from #{st}" do
      start_ok_process(C.p1)
      @process.state = st.to_s
      old_pid = @pid

      expect(@process).not_to receive(:check_crash)
      @process.restart

      expect(@process.pid).not_to eq old_pid
      expect(@process.pid).to be > 0

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(Eye::System.pid_alive?(@process.pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
      expect(@process.states_history.states).to seq(:restarting, :stopping, :down, :starting, :up)

      expect(@process.load_pid_from_file).to eq @process.pid
    end
  end

  [:starting, :restarting, :stopping].each do |st|
    it "not restart from #{st}" do
      @process = process(C.p1)
      @process.state = st.to_s # force set state

      expect(@process).not_to receive(:stop)
      expect(@process).not_to receive(:start)

      expect(@process.restart).to eq nil
      expect(@process.state_name).to eq st
    end
  end

  it "restart process without start command" do
    @process = process(C.p2.merge(:start_command => nil))
    @process.restart
    sleep 1
    expect(@process.unmonitored?).to eq true
  end
end
