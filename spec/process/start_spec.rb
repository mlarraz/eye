require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Start" do

  it "process already runned, started new process" do
    # something already started process
    @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
    expect(Eye::System.pid_alive?(@pid)).to eq true
    File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }

    # should not try to start something
    expect(Eye::System).not_to receive(:daemonize)
    expect(Eye::System).not_to receive(:execute)

    # when start process
    @process = process C.p1
    expect(@process.start).to eq :ok

    # wait while monitoring completely started
    sleep 0.5

    # pid and should be ok
    expect(@process.pid).to eq @pid
    expect(@process.load_pid_from_file).to eq @pid

    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
  end

  it "process started and up, receive command start" do
    @process = process C.p1
    expect(@process.start).to eq({:pid=>@process.pid, :exitstatus => 0})
    sleep 0.5
    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

    expect(@process.start).to eq :ok
    sleep 1
    expect(@process.state_name).to eq :up
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
  end

  [C.p1, C.p2].each do |cfg|
    it "start new process, with config #{cfg[:name]}" do
      @process = process cfg
      expect(@process.start).to eq({:pid=>@process.pid, :exitstatus => 0})

      sleep 0.5

      @pid = @process.pid
      expect(@process.load_pid_from_file).to eq @pid

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
    end

    it "pid_file already exists, but process not, with config #{cfg[:name]}" do
      File.open(C.p1[:pid_file], 'w'){|f| f.write(1234567) }

      @process = process cfg
      expect(@process.start).to eq({:pid=>@process.pid, :exitstatus => 0})

      sleep 0.5

      @pid = @process.pid
      expect(@pid).not_to eq 1234567
      expect(@process.load_pid_from_file).to eq @pid

      expect(@process.state_name).to eq :up
    end

    it "process crashed, with config #{cfg[:name]}" do
      @process = process(cfg.merge(:start_command => cfg[:start_command] + " -r" ))
      expect(@process.start).to eq({:error=>:not_really_running})

      sleep 1

      if cfg[:daemonize]
        expect(@process.load_pid_from_file).to eq nil
      else
        expect(@process.load_pid_from_file).to be > 0
      end

      # should try to up process many times
      expect(@process.states_history.states).to seq(:unmonitored, :starting, :down, :starting)
      expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)

      expect(@process.watchers.keys).to eq []
    end

    it "start with invalid command" do
      @process = process(cfg.merge(:start_command => "asdf asdf1 r f324 f324f 32f44f"))
      expect(@process.wrapped_object).to receive(:check_crash)
      res = @process.start
      expect(res[:error]).to start_with("#<Errno::ENOENT: No such file or directory")

      sleep 0.5

      expect(@process.pid).to eq nil
      expect(@process.load_pid_from_file).to eq nil
      expect([:starting, :down]).to include(@process.state_name)
      expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)
    end

    it "start PROBLEM with stdout permissions" do
      @process = process(cfg.merge(:stdout => "/var/run/1.log"))
      expect(@process.wrapped_object).to receive(:check_crash)
      res = @process.start
      expect(res[:error]).to start_with("#<Errno::EACCES: Permission denied")

      sleep 0.5

      expect(@process.pid).to eq nil
      expect(@process.load_pid_from_file).to eq nil
      expect([:starting, :down]).to include(@process.state_name)
      expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)
    end

    it "start PROBLEM binary permissions" do
      @process = process(cfg.merge(:start_command => "./sample.rb"))
      expect(@process.wrapped_object).to receive(:check_crash)
      res = @process.start
      expect(res[:error]).to start_with("#<Errno::EACCES: Permission denied")

      sleep 0.5

      expect(@process.pid).to eq nil
      expect(@process.load_pid_from_file).to eq nil
      expect([:starting, :down]).to include(@process.state_name)
      expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)
    end

  end

  it "C.p1 pid_file failed to write" do
    @process = process(C.p1.merge(:pid_file => "/tmpasdfasdf/asdfa/dfa/df/ad/fad/fd.pid"))
    res = @process.start
    expect(res).to eq({:error=>:cant_write_pid})

    sleep 1

    expect([:starting, :down]).to include(@process.state_name)
    expect(@process.states_history.states).to seq(:unmonitored, :starting, :down, :starting)
    expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)

    expect(@process.watchers.keys).to eq []
  end

  it "C.p2 pid_file failed to write" do
    pid = "/tmpasdfasdf/asdfa/dfa/df/ad/fad/fd.pid"
    @process = process(C.p2.merge(:pid_file => pid,
      :start_command => "ruby sample.rb -d --pid #{pid} --log #{C.log_name}"))
    res = @process.start
    expect(res).to eq({:error=>:pid_not_found})

    sleep 1

    expect([:starting, :down]).to include(@process.state_name)
    expect(@process.states_history.states).to seq(:unmonitored, :starting, :down, :starting)
    expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)

    expect(@process.watchers.keys).to eq []
  end

  it "long process with #{C.p1[:name]} (with daemonize)" do
    # this is no matter for starting
    @process = process(C.p1.merge(:start_command => C.p1[:start_command] + " --daemonize_delay 3",
      :start_grace => 2.seconds ))
    expect(@process.start).to eq({:pid=>@process.pid, :exitstatus => 0})

    sleep 5
    expect(Eye::System.pid_alive?(@process.pid)).to eq true
    expect(@process.state_name).to eq :up
  end

  it "long process with #{C.p2[:name]}" do
    @process = process(C.p2.merge(:start_command => C.p2[:start_command] + " --daemonize_delay 3",
      :start_timeout => 2.seconds))
    expect(@process.start).to eq({:error=>"#<Timeout::Error: execution expired>"})

    sleep 0.5
    expect(@process.pid).to eq nil
    expect(@process.load_pid_from_file).to eq nil

    expect([:starting, :down]).to include(@process.state_name)

    expect(@process.states_history.states).to seq(:unmonitored, :starting, :down, :starting)
    expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)
  end

  it "long process with #{C.p2[:name]} but start_timeout is OK" do
    @process = process(C.p2.merge(:start_command => C.p2[:start_command] + " --daemonize_delay 3",
      :start_timeout => 10.seconds))
    expect(@process.start).to eq({:pid => @process.pid, :exitstatus => 0})

    expect(@process.load_pid_from_file).to eq @process.pid
    expect(@process.state_name).to eq :up
  end

  # O_o, what checks this spec
  it "blocking start with lock" do
    @process = process(C.p2.merge(:start_command => C.p2[:start_command] + " --daemonize_delay 3 -L #{C.p2_lock}", :start_timeout => 2.seconds))
    expect(@process.start).to eq({:error => "#<Timeout::Error: execution expired>"})

    sleep 0.5
    expect(@process.pid).to eq nil
    expect(@process.load_pid_from_file).to eq nil

    expect([:starting, :down]).to include(@process.state_name)

    expect(@process.states_history.states).to seq(:unmonitored, :starting, :down, :starting)
    expect(@process.states_history.states).to contain_only(:unmonitored, :starting, :down)
  end

  it "bad config daemonize self daemonized process pid the same" do
    # little crazy behaviour, but process after first death, upped from pid_file pid
    # NOT RECOMENDED FOR USE CASE
    @process = process(C.p2.merge(:daemonize => true, :start_grace => 10.seconds))
    old_pid = @process.pid

    expect(@process.start).to eq({:error => :not_really_running})

    sleep 5

    # should reload process from pid_file
    expect(@process.state_name).to eq :up
    expect(@process.pid).not_to eq old_pid
    expect(@process.load_pid_from_file).to eq @process.pid
  end

  it "bad config daemonize self daemonized process pid different" do
    # NOT RECOMENDED FOR USE CASE
    @process = process(C.p2.merge(:daemonize => true, :pid_file => C.p2_pid, :start_grace => 10.seconds,
      :environment => {"FAILSAFE_PID_FILE" => C.just_pid}))
    expect(@process.start).to eq({:error => :not_really_running})
    sleep 0.5
    expect(@process.pid).not_to eq nil
    expect(@process.state_name).to eq :up

    # to ensure kill this process
    sleep 1
    if File.exist?(C.just_pid)
      @process.pid = File.read(C.just_pid).to_i
    end
  end

  it "without start command" do
    @process = process(C.p2.merge(:start_command => nil))
    expect(@process.start).to eq :no_start_command
    sleep 1
    expect(@process.unmonitored?).to eq true
  end

  [:up, :starting, :stopping, :restarting].each do |st|
    it "should not start from #{st}" do
      @process = process(C.p1)
      @process.state = st.to_s # force set state

      expect(Eye::System).not_to receive(:daemonize)
      expect(Eye::System).not_to receive(:execute)

      expect(@process.start).to eq :state_error
      expect(@process.state_name).to eq st

      expect(@process.pid).to eq nil
    end
  end

end
