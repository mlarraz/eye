require File.dirname(__FILE__) + '/../spec_helper'

describe "dependency multi" do
  after :each do
    @pids << @process_a.pid if @process_a && @process_a.alive?
    @pids << @process_b.pid if @process_b && @process_b.alive?
    @pids << @process_c.pid if @process_c && @process_c.alive?
  end

  describe ":c -> :b -> :a" do
    before :each do
      @c = Eye::Controller.new
      silence_warnings { Eye::Control = @c }

      conf = <<-D
        Eye.app :d do
          working_dir "#{C.sample_dir}"
          start_grace 0.3
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

          process(:c) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p3_pid}"

            depend_on :b
          end

        end
      D
      @c.load_content(conf)
      sleep 2.5
      @process_a = @c.process_by_name("a")
      expect(@process_a.state_name).to eq :up
      @pid_a = @process_a.pid
      @process_b = @c.process_by_name("b")
      expect(@process_b.state_name).to eq :up
      @pid_b = @process_b.pid
      @process_c = @c.process_by_name("c")
      expect(@process_c.state_name).to eq :up
      @pid_c = @process_c.pid

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
      expect(Eye::System.pid_alive?(@pid_c)).to eq true
    end

    it "restart :a" do
      @process_a.schedule :restart
      sleep 5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(Eye::System.pid_alive?(@pid_c)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_c.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_c.scheduler_history.states).to eq [:monitor, :restart]
    end

    it "restart :b" do
      @process_b.schedule :restart
      sleep 5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(Eye::System.pid_alive?(@pid_c)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_c.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_c.scheduler_history.states).to eq [:monitor, :restart]
    end

    it "stop :a" do
      @process_a.schedule :stop
      sleep 5

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored
      expect(@process_c.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(Eye::System.pid_alive?(@pid_c)).to eq false
    end

    it "start :c should up other processes" do
      @process_a.schedule :stop
      @process_b.schedule :stop
      @process_c.schedule :stop
      sleep 1

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored
      expect(@process_c.state_name).to eq :unmonitored

      @process_c.schedule :start
      sleep 5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up
    end
  end

  describe ":c -> [:a, :b]" do
    before :each do

      @c = Eye::Controller.new
      silence_warnings { Eye::Control = @c }

      conf = <<-D
        Eye.app :d do
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
          end

          process(:c) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p3_pid}"

            depend_on [:a, :b]
          end

        end
      D
      @c.load_content(conf)
      sleep 2.0
      @process_a = @c.process_by_name("a")
      expect(@process_a.state_name).to eq :up
      @pid_a = @process_a.pid
      @process_b = @c.process_by_name("b")
      expect(@process_b.state_name).to eq :up
      @pid_b = @process_b.pid
      @process_c = @c.process_by_name("c")
      expect(@process_c.state_name).to eq :up
      @pid_c = @process_c.pid

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
      expect(Eye::System.pid_alive?(@pid_c)).to eq true
    end

    it "restart :a" do
      @process_a.schedule :restart
      sleep 5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
      expect(Eye::System.pid_alive?(@pid_c)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up]
      expect(@process_c.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :start]
      expect(@process_c.scheduler_history.states).to eq [:monitor, :restart]
    end

    it "stop :a" do
      @process_a.schedule :stop
      sleep 4

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :unmonitored

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
      expect(Eye::System.pid_alive?(@pid_c)).to eq false
    end

    it "start :c" do
      @process_a.schedule :stop
      @process_b.schedule :stop
      @process_c.schedule :stop
      sleep 1

      expect(@process_a.state_name).to eq :unmonitored
      expect(@process_b.state_name).to eq :unmonitored
      expect(@process_c.state_name).to eq :unmonitored

      @process_c.schedule :start
      sleep 5.5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up
    end
  end

  describe "[:c, :b] -> :a" do
    before :each do
      @c = Eye::Controller.new
      silence_warnings { Eye::Control = @c }

      conf = <<-D
        Eye.app :d do
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

          process(:c) do
            start_command "sleep 100"
            daemonize true
            pid_file "#{C.p3_pid}"

            depend_on :a
          end

        end
      D
      @c.load_content(conf)
      sleep 2.0
      @process_a = @c.process_by_name("a")
      expect(@process_a.state_name).to eq :up
      @pid_a = @process_a.pid
      @process_b = @c.process_by_name("b")
      expect(@process_b.state_name).to eq :up
      @pid_b = @process_b.pid
      @process_c = @c.process_by_name("c")
      expect(@process_c.state_name).to eq :up
      @pid_c = @process_c.pid

      expect(Eye::System.pid_alive?(@pid_a)).to eq true
      expect(Eye::System.pid_alive?(@pid_b)).to eq true
      expect(Eye::System.pid_alive?(@pid_c)).to eq true
    end

    it "restart :a" do
      @process_a.schedule :restart
      sleep 5

      expect(@process_a.state_name).to eq :up
      expect(@process_b.state_name).to eq :up
      expect(@process_c.state_name).to eq :up

      expect(Eye::System.pid_alive?(@pid_a)).to eq false
      expect(Eye::System.pid_alive?(@pid_b)).to eq false
      expect(Eye::System.pid_alive?(@pid_c)).to eq false

      expect(@process_a.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_b.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
      expect(@process_c.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]

      expect(@process_a.scheduler_history.states).to eq [:monitor, :start, :restart, :start]
      expect(@process_b.scheduler_history.states).to eq [:monitor, :restart]
      expect(@process_c.scheduler_history.states).to eq [:monitor, :restart]
    end
  end
end
