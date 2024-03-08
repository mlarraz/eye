require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Trigger Transition" do
  before :each do
    @c = Eye::Controller.new
  end

  describe "delete file on state" do
    before :each do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition, :to => :down, :do => ->{ ::File.delete("#{C.tmp_file}") }
          end
        end
      D

      @c.load_content(cfg)
      sleep 5
      @process = @c.process_by_name("1")
    end

    it "should delete file when stop" do
      File.open(C.tmp_file, 'w'){ |f| f.write "aaa" }
      expect(File.exist?(C.tmp_file)).to eq true
      @process.stop
      expect(File.exist?(C.tmp_file)).to eq false
    end
  end

  describe "delete file on event" do
    before :each do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition, :event => :crashed, :do => ->{ ::File.delete("#{C.tmp_file}") }
          end
        end
      D

      @c.load_content(cfg)
      sleep 5
      @process = @c.process_by_name("1")
    end

    it "should delete file when stop" do
      File.open(C.tmp_file, 'w'){ |f| f.write "aaa" }
      expect(File.exist?(C.tmp_file)).to eq true
      force_kill_pid(@process.pid)
      sleep 5
      expect(File.exist?(C.tmp_file)).to eq false
    end
  end

  describe "call method" do
    before :each do
      cfg = <<-D
        def hashdhfhsdfh(process)
          ::File.delete("#{C.tmp_file}")
        end

        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition, :event => :crashed, :do => :hashdhfhsdfh
          end
        end
      D

      @c.load_content(cfg)
      sleep 5
      @process = @c.process_by_name("1")
    end

    it "should delete file when stop" do
      File.open(C.tmp_file, 'w'){ |f| f.write "aaa" }
      expect(File.exist?(C.tmp_file)).to eq true
      force_kill_pid(@process.pid)
      sleep 5
      expect(File.exist?(C.tmp_file)).to eq false
    end
  end

  describe "multiple triggers" do
    before :each do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition1, :to => :up, :do => ->{ info "touch #{C.tmp_file}"; ::File.open("#{C.tmp_file}", 'w') }
            trigger :transition2, :to => :down, :do => ->{ info "rm #{C.tmp_file}"; ::File.delete("#{C.tmp_file}") }
          end
        end
      D

      @c.load_content(cfg)
      sleep 5
      @process = @c.process_by_name("1")
    end

    it "should delete file when stop" do
      expect(File.exist?(C.tmp_file)).to eq true
      @process.stop
      expect(File.exist?(C.tmp_file)).to eq false
    end
  end

  describe "Kill process children when process crashed or stop" do
    before :each do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("fork") do
            env "PID_NAME" => "#{C.p3_pid}"
            pid_file "#{C.p3_pid}"
            start_command "ruby forking.rb start"
            stop_command "kill -9 {PID}" # SPECIALLY here wrong command for kill parent
            stdall "trash.log"
            monitor_children { children_update_period 1.second }
            check_alive_period 1

            trigger :transition, :event => [:stopped, :crashed], :do => ->{
              process.children.pmap { |pid, c| c.stop }
            }
          end
        end
      D

      @c.load_content(cfg)
      sleep 5
      @process = @c.process_by_name("fork")
      @process.wait_for_condition(15, 0.3) { @process.children.size == 3 }
      expect(@process.state_name).to eq :up
      @pid = @process.pid
      @chpids = @process.children.keys
    end

    it "when process crashed it should kill all children too" do
      expect(@process.children.size).to eq 3
      expect(Eye::System.pid_alive?(@pid)).to eq true
      @chpids.each { |pid| expect(Eye::System.pid_alive?(pid)).to eq true }

      die_process!(@process.pid)
      sleep 10

      expect(Eye::System.pid_alive?(@pid)).to eq false
      @chpids.each { |pid| expect(Eye::System.pid_alive?(pid)).to eq false }

      expect(@process.state_name).to eq :up

      @pids = @process.children.keys # to ensure spec kill them
      expect(@process.children.size).to eq 3
    end

    it "when process restarted should kill children too" do
      expect(@process.children.size).to eq 3
      expect(Eye::System.pid_alive?(@pid)).to eq true
      @chpids.each { |pid| expect(Eye::System.pid_alive?(pid)).to eq true }

      @process.schedule :restart
      sleep 10

      expect(Eye::System.pid_alive?(@pid)).to eq false
      @chpids.each { |pid| expect(Eye::System.pid_alive?(pid)).to eq false }

      expect(@process.state_name).to eq :up

      @pids = @process.children.keys # to ensure spec kill them
      expect(@process.children.size).to eq 3
    end
  end

  describe "catch errors" do
    it "catch just error in do" do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition1, :to => :up, :do => ->{ info "some"; 1/0 }
          end
        end
      D

      @c.load_content(cfg)
      @process = @c.process_by_name("1")
      @process.wait_for_condition(3, 0.3) { @process.state_name == :up }

      sleep 2
      expect(@process.alive?).to eq true
      expect(@process.state_name).to eq :up
    end

    it "catch just error in do with NoMethodError" do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition1, :to => :up, :do => ->{ info "some"; wtf? }
          end
        end
      D

      @c.load_content(cfg)
      @process = @c.process_by_name("1")
      @process.wait_for_condition(3, 0.3) { @process.state_name == :up }

      sleep 2
      expect(@process.alive?).to eq true
      expect(@process.state_name).to eq :up
    end

    it "catch error when unknown symbol" do
      cfg = <<-D
        Eye.application("bla") do
          working_dir "#{C.sample_dir}"
          process("1") do
            pid_file "#{C.p1_pid}"
            start_command "sleep 30"
            daemonize true
            trigger :transition1, :to => :up, :do => :sdfsdfasdfsdfdd
          end
        end
      D

      @c.load_content(cfg)
      @process = @c.process_by_name("1")
      @process.wait_for_condition(3, 0.3) { @process.state_name == :up }

      sleep 2
      expect(@process.alive?).to eq true
      expect(@process.state_name).to eq :up
    end
  end

end
