require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "StopChildren State" do
  before :each do
    @c = Eye::Controller.new
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
          trigger :stop_children
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
