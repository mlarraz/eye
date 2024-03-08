require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Process Controller" do

  describe "monitor" do
    it "monitor should call start, as the auto_start is default" do
      @process = process C.p1

      expect(@process).to receive(:start).and_call_original
      @process.monitor
      sleep 1

      expect(@process.state_name).to eq :up
    end

    it "without auto_start and process not running" do
      @process = process C.p1.merge(:auto_start => false)
      @process.monitor
      sleep 1

      expect(@process.state_name).to eq :unmonitored
    end

    it "without auto_start and process already running" do
      @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
      expect(Eye::System.pid_alive?(@pid)).to eq true
      File.open(C.p1[:pid_file], 'w'){|f| f.write(@pid) }
      sleep 2

      @process = process C.p1.merge(:auto_start => false)
      @process.monitor
      sleep 1

      expect(@process.state_name).to eq :up
      expect(@process.pid).to eq @pid
    end

  end

  describe "unmonitor" do
    [C.p1, C.p2].each do |cfg|
      it "should just forget about any process #{cfg[:name]}" do
        start_ok_process(cfg)
        old_pid = @process.pid

        @process.unmonitor

        expect(Eye::System.pid_alive?(old_pid)).to eq true

        expect(@process.pid).to eq nil
        expect(@process.state_name).to eq :unmonitored

        expect(@process.watchers.keys).to eq []
        expect(@process.load_pid_from_file).to eq old_pid

        sleep 1

        # event if something now kill the process
        die_process!(old_pid)

        # nothing try to up it
        sleep 5

        expect(@process.state_name).to eq :unmonitored
        expect(@process.load_pid_from_file).to eq old_pid
      end
    end
  end

  describe "delete" do
    it "delete monitoring, not kill process" do
      start_ok_process
      old_pid = @process.pid

      @process.delete
      expect(Eye::System.pid_alive?(old_pid)).to eq true
      sleep 0.3
      expect(@process.alive?).to eq false

      @process = nil
    end

    it "if stop_on_delete process die" do
      start_ok_process(C.p1.merge(:stop_on_delete => true))
      old_pid = @process.pid

      @process.delete
      expect(Eye::System.pid_alive?(old_pid)).to eq false
      sleep 0.3
      expect(@process.alive?).to eq false

      @process = nil
    end
  end

  describe "stop" do
    it "stop kill process, and moving to unmonitored" do
      start_ok_process

      @process.stop

      expect(Eye::System.pid_alive?(@pid)).to eq false
      expect(@process.state_name).to eq :unmonitored
      expect(@process.states_history.states).to end_with(:down, :unmonitored)

      # should clear pid
      expect(@process.pid).to eq nil
    end

    it "if cant kill process, moving to unmonitored too" do
      start_ok_process(C.p1.merge(:stop_command => "which ruby"))

      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      @process.stop

      expect(Eye::System.pid_alive?(@pid)).to eq true
      expect(@process.state_name).to eq :unmonitored
      expect(@process.states_history.states).to end_with(:stopping, :unmonitored)

      # should clear pid
      expect(@process.pid).to eq nil
      expect(@process.watchers.keys).to eq []
    end
  end

  describe "process cant start, crash each time" do
    before :each do
      @process = process(C.p2.merge(:start_command => C.p2[:start_command] + " -r" ))
      @process.send_call :command => :start
    end

    it "we send command to stop it" do
      # process flapping here some times
      sleep 10

      # now send stop command
      @process.send_call :command => :stop
      sleep 7

      # process should be stopped here
      expect(@process.state_name).to eq :unmonitored
    end

    it "we send command to unmonitor it" do
      # process flapping here some times
      sleep 10

      # now send stop command
      @process.send_call :command => :unmonitor
      sleep 7

      # process should be stopped here
      expect(@process.state_name).to eq :unmonitored
    end
  end

  describe "signal" do
    before :each do
      @process = process(C.p1)
      @process.pid = 122345
    end

    it "mock send_signal" do
      expect(@process).to receive(:send_signal).with(9)
      @process.signal(9)

      expect(@process).to receive(:send_signal).with('9')
      @process.signal('9')
    end
  end

  describe "syslog" do
    before :each do
      @c = Eye::Controller.new
      conf = <<-D
        Eye.app :bla do
          process(:a) do
            start_command "ruby -e 'loop {p 1; sleep 1; File.open(\\"#{C.tmp_file}\\", \\"w\\")}'"
            daemonize true
            pid_file "#{C.p1_pid}"
            start_grace 3.seconds
            stdall syslog
          end
        end
      D
      expect(File.exist?(C.tmp_file)).to eq false
      @c.load_content(conf)
      @process = @c.process_by_name(:a)
      sleep 4.5
    end

    it "should ok up process" do
      expect(@process.state_name).to eq :up
      expect(File.exist?(C.tmp_file)).to eq true
      args = Eye::SystemResources.args(@process.pid)
      expect(args).to start_with('ruby')
      expect(args).not_to include('sh')
    end
  end

end
