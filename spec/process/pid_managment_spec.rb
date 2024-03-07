require File.dirname(__FILE__) + '/../spec_helper'

[C.p1, C.p2].each do |cfg|
  describe "Process Pid Managment '#{cfg[:name]}'" do

    it "crashed of process should remove pid_file for daemonize only" do
      start_ok_process(cfg)
      die_process!(@pid)

      expect(@process).to receive(:start) # stub start for clean test

      sleep 4

      if cfg[:daemonize]
        expect(@process.load_pid_from_file).to eq nil
      else
        expect(@process.load_pid_from_file).to eq @pid
      end
    end

    it "someone remove pid_file. should rewrite" do
      start_ok_process(cfg)
      old_pid = @pid
      expect(File.exist?(cfg[:pid_file])).to eq true

      FileUtils.rm(cfg[:pid_file]) # someone removes it (bad man)
      expect(File.exist?(cfg[:pid_file])).to eq false

      sleep 5 # wait until monitor understand it

      expect(File.exist?(cfg[:pid_file])).to eq true
      expect(@process.pid).to eq old_pid
      expect(@process.load_pid_from_file).to eq @process.pid
      expect(@process.state_name).to eq :up
    end

    it "someone rewrite pid_file. should rewrite for daemonize only" do
      start_ok_process(cfg)
      old_pid = @pid
      expect(@process.load_pid_from_file).to eq @pid

      File.open(cfg[:pid_file], 'w'){|f| f.write(99999) }
      expect(@process.load_pid_from_file).to eq 99999

      sleep 5 # wait until monitor understand it

      if cfg[:daemonize]
        expect(@process.load_pid_from_file).to eq @pid
      else
        expect(@process.load_pid_from_file).to eq 99999
      end

      expect(@process.pid).to eq old_pid
      expect(@process.state_name).to eq :up
    end

    it "someone rewrite pid_file. and ctime > limit, should rewrite for both" do
      start_ok_process(cfg.merge(:revert_fuckup_pidfile_grace => 3.seconds))
      old_pid = @pid
      expect(@process.load_pid_from_file).to eq @pid

      File.open(cfg[:pid_file], 'w'){|f| f.write(99999) }
      expect(@process.load_pid_from_file).to eq 99999

      sleep 8 # wait until monitor understand it

      expect(@process.load_pid_from_file).to eq @pid

      expect(@process.pid).to eq old_pid
      expect(@process.state_name).to eq :up
    end

  end
end
