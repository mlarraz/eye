require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::ChildProcess" do

  before :each do
    @pid = Eye::System.daemonize(C.p1[:start_command], C.p1)[:pid]
    expect(Eye::System.pid_alive?(@pid)).to eq true
    sleep 0.5
    @parent = OpenStruct.new(:pid => @parent, :scheduler_history => Eye::Process::StatesHistory.new(50))
  end

  it "some process was declared by my child" do
    @process = Eye::ChildProcess.new(@pid, {}, nil, @parent)
    expect(@process.pid).to eq @pid

    expect(@process.watchers.keys).to eq []
  end

  describe "restart" do

    it "kill by default command" do
      @process = Eye::ChildProcess.new(@pid, {}, nil, @parent)
      @process.schedule :restart

      sleep 0.5
      expect(Eye::System.pid_alive?(@pid)).to eq false
    end

    it "kill by stop command" do
      @process = Eye::ChildProcess.new(@pid, {:stop_command => "kill -9 {PID}"}, nil, @parent)
      @process.schedule :restart

      sleep 0.5
      expect(Eye::System.pid_alive?(@pid)).to eq false
    end

    it "kill by stop command with PARENT_PID" do
      # emulate with self pid as parent_pid
      @process = Eye::ChildProcess.new(@pid, {:stop_command => "kill -9 {PARENT_PID}"}, nil, OpenStruct.new(:pid => @pid))
      @process.schedule :restart

      sleep 0.5
      expect(Eye::System.pid_alive?(@pid)).to eq false
    end

    it "should not restart with wrong command" do
      @process = Eye::ChildProcess.new(@pid, {:stop_command => "kill -0 {PID}"}, nil, @parent)
      @process.schedule :restart

      sleep 0.5
      expect(Eye::System.pid_alive?(@pid)).to eq true
    end
  end

end
