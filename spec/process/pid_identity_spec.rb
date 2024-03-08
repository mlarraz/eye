require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "check pid identity" do
  it "check_identity method" do
    @process = process(C.p1)
    @process.start

    @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
    File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }
    change_ctime(C.p1[:pid_file], Time.parse('2010-01-01'))

    expect(@process.state_name).to eq :up
    @process.send :check_identity
    expect(@process.state_name).to eq :down
    expect(@process.pid).to eq nil
  end

  describe "monitor new process" do
    it "no identity, no process" do
      @process = process(C.p1)
      expect(@process.get_identity).to be_nil

      @process.start
      expect(@process.state_name).to eq :up

      expect(@process.get_identity).to be_within(1).of(Time.now)
      expect(@process.compare_identity).to eq :ok
    end

    it "identity, process, identity is ok" do
      @process = process(C.p1)

      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }

      @process.start
      expect(@process.state_name).to eq :up
      expect(@process.pid).to eq @pid

      expect(@process.get_identity).to be_within(5).of(Time.now)
      expect(@process.compare_identity).to eq :ok
    end

    it "identity, process, identity is bad, pid_file is very old" do
      @process = process(C.p1)

      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }
      change_ctime(C.p1[:pid_file], Time.parse('2010-01-01'))
      expect(@process.get_identity.year).to eq 2010
      expect(@process.compare_identity).to eq :no_pid

      @process.start
      expect(@process.state_name).to eq :up
      expect(@process.pid).not_to eq @pid # !!!!

      expect(Eye::System.pid_alive?(@pid)).to eq true
      expect(Eye::System.pid_alive?(@process.pid)).to eq true

      expect(@process.get_identity).to be_within(2).of(Time.now)
      expect(@process.compare_identity).to eq :ok

      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "check_identity disabled, identity, process, identity is bad, pid_file is very old" do
      @process = process(C.p1.merge(:check_identity => false))

      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }
      change_ctime(C.p1[:pid_file], Time.parse('2010-01-01'))
      expect(@process.get_identity.year).to eq 2010
      expect(@process.compare_identity).to eq :ok

      @process.start
      expect(@process.state_name).to eq :up
      expect(@process.pid).to eq @pid

      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.compare_identity).to eq :ok

      expect(@process.load_pid_from_file).to eq @process.pid
    end
  end

  it "process changed identity while running" do
    @process = start_ok_process(C.p1.merge(:check_identity_period => 2))
    old_pid = @process.pid
    @pids << old_pid

    change_ctime(C.p1[:pid_file], 5.days.ago)
    sleep 5

    # here process should mark as crash, and restart again
    expect(@process.states_history.states).to eq [:unmonitored, :starting, :up, :down, :starting, :up]
    expect(@process.scheduler_history.states).to eq [:check_crash, :restore]

    expect(@process.state_name).to eq :up
    expect(@process.pid).not_to eq old_pid

    expect(Eye::System.pid_alive?(old_pid)).to eq true
    expect(Eye::System.pid_alive?(@process.pid)).to eq true

    expect(@process.load_pid_from_file).to eq @process.pid
  end

  it "just touch should not crash process" do
    @process = start_ok_process(C.p1.merge(:check_identity_period => 2, :check_identity_grace => 3))
    old_pid = @process.pid
    @pids << old_pid

    sleep 5

    change_ctime(C.p1[:pid_file], Time.now, true)
    sleep 5

    # here process should mark as crash, and restart again
    expect(@process.states_history.states).to eq [:unmonitored, :starting, :up]

    expect(@process.state_name).to eq :up
    expect(@process.pid).to eq old_pid
    expect(@process.load_pid_from_file).to eq @process.pid
  end

  it "check_identity disabled, process changed identity while running" do
    @process = start_ok_process(C.p1.merge(:check_identity_period => 2, :check_identity => false))
    old_pid = @process.pid
    @pids << old_pid

    change_ctime(C.p1[:pid_file], 5.days.ago)
    sleep 5

    # here process should mark as crash, and restart again
    expect(@process.states_history.states).to eq [:unmonitored, :starting, :up]

    expect(@process.state_name).to eq :up
    expect(@process.pid).to eq old_pid

    expect(Eye::System.pid_alive?(old_pid)).to eq true
    expect(@process.load_pid_from_file).to eq @process.pid
  end

  describe "pid_file externally changed" do
    it "pid file was rewritten, but process with ok identity" do
      @process = start_ok_process(C.p2.merge(:check_identity_period => 2, :auto_update_pidfile_grace => 3, :check_identity_grace => 3))
      old_pid = @process.pid
      @pids << old_pid

      sleep 5

      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      File.open(C.p2[:pid_file], 'w'){|f| f.write(@pid) }

      sleep 5

      # here process should mark as crash, and restart again
      expect(@process.states_history.states).to eq [:unmonitored, :starting, :up]

      expect(@process.state_name).to eq :up
      expect(@process.pid).to eq @pid

      expect(Eye::System.pid_alive?(old_pid)).to eq true
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "pid file was rewritten, but process with bad identity" do
      @process = start_ok_process(C.p2.merge(:check_identity_period => 20, :auto_update_pidfile_grace => 3, :revert_fuckup_pidfile_grace => 5,
        :check_identity_grace => 3))
      old_pid = @process.pid
      @pids << old_pid

      sleep 5

      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      File.open(C.p2[:pid_file], 'w'){|f| f.write(@pid) }
      change_ctime(C.p2[:pid_file], 5.days.ago)

      sleep 7

      # here process should mark as crash, and restart again
      expect(@process.states_history.states).to eq [:unmonitored, :starting, :up]

      expect(@process.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid)).to eq true
      expect(Eye::System.pid_alive?(@process.pid)).to eq true
      expect(@pid).not_to eq @process.pid

      expect(@process.load_pid_from_file).to eq @process.pid
    end
  end

  describe "process send to stop, check identity before" do
    it "stop, identity bad -> just mark as crashed and unmonitored, remove pid_file" do
      @process = start_ok_process
      old_pid = @process.pid
      @pids << old_pid
      sleep 2
      change_ctime(C.p1[:pid_file], 5.days.ago)
      sleep 2
      @process.stop
      expect(Eye::System.pid_alive?(old_pid)).to eq true
      expect(@process.load_pid_from_file).to eq nil
    end

    it "restart, identity bad -> just mark as crashed and unmonitored, remove pid_file" do
      @process = start_ok_process
      old_pid = @process.pid
      @pids << old_pid
      sleep 2
      change_ctime(C.p1[:pid_file], 5.days.ago)
      sleep 2
      @process.restart
      sleep 2
      expect(@process.pid).not_to eq old_pid
      expect(Eye::System.pid_alive?(old_pid)).to eq true
      expect(Eye::System.pid_alive?(@process.pid)).to eq true
      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "restart_command, identity bad -> just mark as crashed and unmonitored, remove pid_file" do
      @process = start_ok_process(C.p1.merge(:restart_command => "kill -USR1 {PID}"))
      old_pid = @process.pid
      @pids << old_pid
      sleep 2
      expect(@process).not_to receive(:execute)
      change_ctime(C.p1[:pid_file], 5.days.ago)
      sleep 2
      @process.restart
      sleep 3
      expect(@process.pid).not_to eq old_pid
      expect(Eye::System.pid_alive?(old_pid)).to eq true
      expect(Eye::System.pid_alive?(@process.pid)).to eq true
      expect(@process.load_pid_from_file).to eq @process.pid
    end
  end

end
