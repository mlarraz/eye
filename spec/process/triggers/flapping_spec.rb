require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Flapping" do
  before :each do
    @c = C.p1.merge(
      :triggers => C.flapping(:times => 4, :within => 10)
    )
  end

  it "should create trigger from config" do
    start_ok_process(@c)

    triggers = @process.triggers
    expect(triggers.size).to eq 1

    expect(triggers.first.class).to eq Eye::Trigger::Flapping
    expect(triggers.first.within).to eq 10
    expect(triggers.first.times).to eq 4
    expect(triggers.first.inspect.size).to be > 100
  end

  it "should check speedy flapping by default" do
    start_ok_process(C.p1)

    triggers = @process.triggers
    expect(triggers.size).to eq 1

    expect(triggers.first.class).to eq Eye::Trigger::Flapping
    expect(triggers.first.within).to eq 10
    expect(triggers.first.times).to eq 10
  end

  it "process flapping" do
    @process = process(@c.merge(:start_command => @c[:start_command] + " -r"))
    @process.schedule :start

    allow(@process).to receive(:notify).with(:info, anything)
    expect(@process.wrapped_object).to receive(:notify).with(:error, anything)

    sleep 13

    # check flapping happens here

    expect(@process.state_name).to eq :unmonitored
    expect(@process.watchers.keys).to eq []
    expect(@process.states_history.states.last(2)).to eq [:down, :unmonitored]
    expect(@process.load_pid_from_file).to eq nil
  end

  it "process flapping emulate with kill" do
    @process = process(@c.merge(:triggers => C.flapping(:times => 3, :within => 8)))

    @process.start

    3.times do
      die_process!(@process.pid)
      sleep 3
    end

    expect(@process.state_name).to eq :unmonitored
    expect(@process.watchers.keys).to eq []

    # ! should switched to unmonitored from down status
    expect(@process.states_history.states.last(2)).to eq [:down, :unmonitored]
    expect(@process.load_pid_from_file).to eq nil
  end

  it "process flapping, and then send to start and fast kill, should ok started" do
    @process = process(@c.merge(:triggers => C.flapping(:times => 3, :within => 15)))

    @process.start

    3.times do
      die_process!(@process.pid)
      sleep 3
    end

    expect(@process.state_name).to eq :unmonitored
    expect(@process.watchers.keys).to eq []

    @process.start
    expect(@process.state_name).to eq :up

    die_process!(@process.pid)
    sleep 4
    expect(@process.state_name).to eq :up

    expect(@process.load_pid_from_file).to eq @process.pid
  end

  it "flapping not happens" do
    @process = process(@c)
    @process.schedule :start

    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restore }).and_call_original
    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :check_crash }).and_call_original
    expect(@process.wrapped_object).not_to receive(:schedule).with(:unmonitor)

    sleep 2

    2.times do
      die_process!(@process.pid)
      sleep 3
    end

    sleep 2

    expect(@process.state_name).to eq :up
    expect(@process.load_pid_from_file).to eq @process.pid
  end
end
