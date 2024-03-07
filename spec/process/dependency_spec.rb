require File.dirname(__FILE__) + '/../spec_helper'

describe "dependency" do
  after :each do
    @pids << @process_a.pid if @process_a && @process_a.alive?
    @pids << @process_b.pid if @process_b && @process_b.alive?
    @pids << @process_c.pid if @process_c && @process_c.alive?
  end

  describe "start" do
    before :each do
      @c = Eye::Controller.new
      silence_warnings { Eye::Control = @c }

      conf = <<-D
        # dependency :b -> :a
        #   :b want :a to be upped

        Eye.app :d do
          auto_start false
          working_dir "#{C.sample_dir}"

          process(:a) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p1_pid}"
            start_grace 3.seconds
          end

          process(:b) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p2_pid}"
            start_grace 0.5

            depend_on :a, :wait_timeout => 5.seconds
          end

        end
      D
      @c.load_content(conf)
      sleep 0.5
      @process_a = @c.process_by_name("a")
      expect(@process_a.state_name).to eq :unmonitored
      @pid_a = @process_a.pid
      @process_b = @c.process_by_name("b")
      expect(@process_b.state_name).to eq :unmonitored
    end

    it "start :a" do
      @process_a.send_call :command => :start
      sleep 4

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :unmonitored

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :unmonitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor]
    end

    it "start :b" do
      @process_b.send_call :command => :start
      sleep 4.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :unmonitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor, :start]
    end

    it "start :b, and :a not started (crashed)" do
      @process_a.config[:start_command] = "asdfasdf asf "
      @process_b.send_call :command => :start

      expect(@process_b).not_to receive(:daemonize_process)
      sleep 7

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored

      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :unmonitored]
    end

    it "start :b, and :a not started (crashed), than a somehow up, should reschedule and up" do
      @process_a.config[:start_command] = "asdfasdf asf "
      @process_a.config[:start_grace] = 1.seconds
      @process_b.config[:triggers].detect{|k, v| k.to_s =~ /wait_dep/}[1][:retry_after] = 2.seconds
      @process_b.send_call :command => :start
      sleep 6
      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored

      @process_a.config[:start_command] = "sleep 100"
      sleep 3.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :unmonitored, :starting, :up]
    end

    it "start :b, and :a started after big timeout (> wait_timeout)" do
      @process_a.config[:start_grace] = 6.seconds
      @process_b.config[:triggers].detect{|k, v| k.to_s =~ /wait_dep/}[1][:retry_after] = 2.seconds
      @process_b.send_call :command => :start
      sleep 10

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :unmonitored, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :unmonitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor, :start, :start]
    end

    it "start :b and should_start = false" do
      @process_b.config[:triggers].detect{|k, v| k.to_s =~ /wait_dep/}[1][:should_start] = false
      @process_b.config[:triggers].detect{|k, v| k.to_s =~ /wait_dep/}[1][:retry_after] = 2.seconds

      @process_b.send_call :command => :start
      sleep 4

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :starting

      # then somehow a :up
      @process_a.start
      sleep 3

      # now b should start automatically
      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :unmonitored, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :unmonitor]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor, :start, :start]
    end
  end

  describe "some actions" do
    before :each do
      @c = Eye::Controller.new
      silence_warnings { Eye::Control = @c }

      conf = <<-D
        # dependency :b -> :a
        #   :b want :a to be upped

        Eye.app :app do
          working_dir "#{C.sample_dir}"
          start_grace 0.5
          check_alive_period 0.5

          process(:a) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p1_pid}"
          end

          process(:b) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p2_pid}"

            depend_on :a
          end

        end
      D
      @c.load_content(conf)
      @process_a = @c.process_by_name("a")
      @process_b = @c.process_by_name("b")
      [@process_a, @process_b].each do |p|
        p.wait_for_condition(2, 0.3) { p.state_name == :up }
      end
      @pid_a = @process_a.pid
      @pid_b = @process_b.pid
      @pids << @process_a.pid
      @pids << @process_b.pid

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
    end

    it "crashed :a, should restore :a and restart :b" do
      Eye::System.send_signal(@process_a.pid, 9)
      sleep 6
      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(@process_a.pid).not_to eq @pid_a
      expect(@process_b.pid).not_to eq @pid_b

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states[0,4]).to eq [:monitor, :start, :check_crash, :restore]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :restart]
    end

    it "crashed :b, should only restore :b" do
      Eye::System.send_signal(@process_b.pid, 9)
      sleep 2

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(Eye::System.pid_alive?(@process_b.pid)).to eq true

      expect(@pid_a).to eq @process_a.pid
      expect(@pid_b).not_to eq @process_b.pid

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :check_crash, :restore]
    end

    it "stop :a, should stop :b" do
      @process_a.stop
      sleep 1

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :stopping, :down, :unmonitored]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :stopping, :down, :unmonitored]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :stop]
    end

    it "stop :b" do
      @process_b.stop
      sleep 1

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :stopping, :down, :unmonitored]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor]
    end

    it "unmonitor :a, should unmonitor :b" do
      @process_a.unmonitor
      sleep 1

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :unmonitored]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :unmonitored]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor]
    end

    it "unmonitor :b" do
      @process_b.unmonitor
      sleep 1

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :unmonitored]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor]
    end

    it "restart :a, should restart :b" do
      @process_a.restart
      sleep 2

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :start, :check_crash, :restore]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :restart]
    end

    it "restart :b" do
      @process_b.restart
      sleep 1

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor]
    end

    it "restart send to group" do
      @c.command :restart, 'app'
      sleep 3.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :restart]
    end

    it ":a was deleted, should successfully restart :b" do
      @c.command :delete, 'a'

      @process_b.restart
      sleep 1

      expect(@process_b.state_name).to eq :up
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_b.scheduler_history.states).to eq [:monitor]
    end

    it ":b was deleted, should successfully restart :a" do
      @c.command :delete, 'b'

      @process_a.restart
      sleep 1

      expect(@process_a.state_name).to eq :up
      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
    end

    it ":b was unmonitored, should successfully restart :a, and not restart :b" do
      @c.command :unmonitor, 'b'
      sleep 0.2

      @process_a.restart
      sleep 1.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :unmonitored
      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor]
    end

    it ":b was unmonitored, when restart group, should restart a and b" do
      @c.command :unmonitor, 'b'
      sleep 0.2

      @c.command :restart, 'app'
      sleep 2.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :unmonitor, :restart]
    end
  end
end
