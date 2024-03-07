require File.dirname(__FILE__) + '/../spec_helper'

[C.p1, C.p2].each do |cfg|
  describe "Process Pid Managment emulate '#{cfg[:name]}'" do

    it "EMULATE UNICORN someone rewrite pid_file and process die (should read actual pid from file)" do
      start_ok_process(cfg)
      old_pid = @pid

      # rewrite by another :)
      @pid = Eye::System.daemonize("ruby sample.rb", {:environment => {"ENV1" => "SECRET1"},
        :working_dir => cfg[:working_dir], :stdout => @log})[:pid]

      File.open(cfg[:pid_file], 'w'){|f| f.write(@pid) }

      die_process!(old_pid)

      sleep 5 # wait until monitor upping process

      expect(@process.pid).to eq @pid
      expect(old_pid).not_to eq @pid

      expect(Eye::System.pid_alive?(old_pid)).to eq false
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
      expect(@process.load_pid_from_file).to eq @process.pid
    end

    it "EMULATE haproxy(#52), pid_file was rewritten, and old process not die, new process alive, eye should monitor new pid (only for daemonize false)" do
      start_ok_process(cfg.merge(:auto_update_pidfile_grace => 3.seconds))
      old_pid = @pid

      # up another process
      @pid = Eye::System.daemonize("ruby sample.rb", {:environment => {"ENV1" => "SECRET1"},
        :working_dir => cfg[:working_dir], :stdout => @log})[:pid]
      File.open(cfg[:pid_file], 'w'){|f| f.write(@pid) }

      sleep 5 # here eye should understand that pid-file changed

      if cfg[:daemonize]
        expect(@process.pid).to eq old_pid
        expect(old_pid).not_to eq @pid

        # because eye rewrite it
        expect(@process.load_pid_from_file).to eq old_pid
      else
        expect(@process.pid).to eq @pid
        expect(old_pid).not_to eq @pid

        expect(@process.load_pid_from_file).to eq @pid
      end

      expect(Eye::System.pid_alive?(old_pid)).to eq true
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      @pids << old_pid # to gc this process too
    end

    it "EMULATE haproxy(#52), pid_file was rewritten, and old process not die, and not new process not alive, eye should not monitor new pid (only for daemonize false)" do
      start_ok_process(cfg.merge(:revert_fuckup_pidfile_grace => 5.seconds))
      old_pid = @pid

      # just rewrite pid_file with fake pid
      @pid = 89999
      File.open(cfg[:pid_file], 'w'){|f| f.write(@pid) }

      sleep 7 # here eye should understand that pid-file changed

      expect(@process.pid).to eq old_pid
      expect(old_pid).not_to eq @pid
      expect(@process.load_pid_from_file).to eq old_pid

      expect(Eye::System.pid_alive?(old_pid)).to eq true

      expect(@process.state_name).to eq :up
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]

      @pids << old_pid # to gc this process too
    end
  end
end
