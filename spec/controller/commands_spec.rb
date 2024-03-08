require File.dirname(__FILE__) + '/../spec_helper'

describe "comamnd spec" do
  subject{ c = Eye::Controller.new; c.load(fixture("dsl/load.eye")); c }

  before :each do
    @apps = subject.applications

    @app1 = @apps.first
    @app2 = @apps.last

    @gr1 = @app1.groups[0]
    @gr2 = @app1.groups[1]
    @gr3 = @app1.groups[2]
    @gr4 = @app2.groups[0]

    @p1 = @gr1.processes[0]
    @p2 = @gr1.processes[1]
    @p3 = @gr2.processes[0]
    @p4 = @gr3.processes[0]
    @p5 = @gr3.processes[1]
    @p6 = @gr4.processes[0]
  end

  describe "remove objects" do
    it "remove app" do
      subject.remove_object_from_tree(@app2)
      expect(subject.applications.size).to eq 1
      expect(subject.applications.first).to eq @app1
    end

    it "remove group" do
      subject.remove_object_from_tree(@gr1)
      expect(@app1.groups).not_to include(@gr1)

      subject.remove_object_from_tree(@gr2)
      expect(@app1.groups).not_to include(@gr2)

      subject.remove_object_from_tree(@gr3)
      expect(@app1.groups).not_to include(@gr3)

      expect(@app1.groups).to be_empty
    end

    it "remove process" do
      subject.remove_object_from_tree(@p1)
      expect(@gr1.processes).not_to include(@p1)

      subject.remove_object_from_tree(@p2)
      expect(@gr1.processes).not_to include(@p2)

      expect(@gr1.processes).to be_empty
    end
  end

  it "unknown" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.command(:st33art, "2341234")).to eq :unknown_command
  end

  it "ping" do
    expect(subject.command(:ping)).to eq :pong
  end

  it "quit" do
    expect(Eye::System).to receive(:send_signal).with($$, :TERM)
    expect(Eye::System).to receive(:send_signal).with($$, :KILL)
    subject.command(:quit)
  end

  describe "apply" do
    it "command load" do
      res = subject.command(:load, fixture("dsl/load.eye"))
      expect(res.class).to eq Hash
    end

    it "nothing" do
      expect(subject.load(fixture("dsl/load.eye"))).to be_ok
      expect(subject.apply(["2341234"], :command => :start)).to eq({:result => []})
    end

    it "unknown" do
      expect(subject.load(fixture("dsl/load.eye"))).to be_ok
      expect(subject.apply(["2341234"], :command => :st33art)).to eq({:result=>[]})
    end

    [:start, :stop, :restart, :unmonitor].each do |cmd|
      it "should user_schedule #{cmd}" do
        sleep 0.3
        expect_any_instance_of(Eye::Process).not_to receive(:user_schedule).with(:command => cmd)

        expect(@p1).to receive(:user_schedule).with(:command => cmd)

        subject.apply %w{p1}, :command => cmd, :some_flag => true
      end
    end

    it "unmonitor group" do
      sleep 0.5
      cmd = :unmonitor

      subject.apply %w{gr1}, :command => cmd
      sleep 0.5

      expect(@p1.scheduler_history.states).to eq [:monitor, :unmonitor]
      expect(@p2.scheduler_history.states).to eq [:monitor, :unmonitor]
      expect(@p3.scheduler_history.states).to eq [:monitor]
    end

    it "stop group with skip_group_action for @p2" do
      sleep 0.5
      cmd = :stop

      allow(@p2).to receive(:skip_group_action?).with(:stop) { true }

      subject.apply %w{gr1}, :command => cmd
      sleep 0.5

      expect(@p1.scheduler_history.states).to eq [:monitor, :stop]
      expect(@p2.scheduler_history.states).to eq [:monitor]
      expect(@p3.scheduler_history.states).to eq [:monitor]
    end

    it "delete obj" do
      sleep 0.5
      expect_any_instance_of(Eye::Process).not_to receive(:send_call).with(:command => :delete)

      expect(@p1).to receive(:send_call).with(:command => :delete)
      subject.apply %w{p1}, :command => :delete

      expect(subject.all_processes).not_to include(@p1)
      expect(subject.all_processes).to include(@p2)
    end

    it "user_command" do
      expect(@p1).to receive(:send_call).with(:command => :user_command, :args => %w{jopa})
      subject.apply %w{p1}, :command => :user_command, :args => %w{jopa}
    end
  end

end
