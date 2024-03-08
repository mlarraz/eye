require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Intergration chains" do
  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration.erb"))
    end

    @samples = @controller.all_groups.detect{|c| c.name == 'samples'}
    @samples.config[:chain] = C.restart_async
  end

  after :each do
    stop_controller
  end

  it "restart group with chain sync" do
    @samples.config[:chain] = C.restart_sync

    @controller.command(:restart, 'samples')
    sleep 15 # while they restarting

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).not_to eq @old_pid1
    expect(@p2.pid).not_to eq @old_pid2
    expect(@p3.pid).to eq @old_pid3

    r1 = @p1.states_history.detect{|c| c[:state] == :restarting}[:at]
    r2 = @p2.states_history.detect{|c| c[:state] == :restarting}[:at]

    # >8 because, grace start, and grace stop added
    expect(r2 - r1).to be >= 8
  end

  it "restart group with chain async" do
    @controller.command(:restart, 'samples')
    sleep 15 # while they restarting

    expect(@processes.map(&:state_name).uniq).to eq [:up]
    expect(@p1.pid).not_to eq @old_pid1
    expect(@p2.pid).not_to eq @old_pid2
    expect(@p3.pid).to eq @old_pid3

    r1 = @p1.states_history.detect{|c| c[:state] == :restarting}[:at]
    r2 = @p2.states_history.detect{|c| c[:state] == :restarting}[:at]

    # restart sent, in 5 seconds to each
    expect(r2 - r1).to be_within(0.2).of(5)
  end

  it "process have skip_group_action, skip that action" do
    allow(@p2).to receive(:skip_group_action?).with(:restart) { true }

    @controller.command(:restart, 'samples')
    sleep 9

    expect(@p1.scheduler_history.states).to eq [:monitor, :restart]
    expect(@p2.scheduler_history.states).to eq [:monitor]
  end

  it "if processes dead in chain restart, nothing raised" do
    @controller.command(:restart, 'samples')
    sleep 3

    @pids += @controller.all_processes.map(&:pid) # to ensure kill this processes after spec

    @p1.terminate
    @p2.terminate

    sleep 3

    # nothing happens
    expect(@samples.alive?).to eq true
  end

  it "chain breaker breaks current chain and all pending requests" do
    @controller.command(:restart, 'samples')
    @controller.command(:stop, 'samples')
    sleep 0.5

    expect(@samples.scheduler_current_command).to eq :restart
    expect(@samples.scheduler_commands_list).to eq [:stop]

    @controller.command(:break_chain, 'samples')
    sleep 3
    expect(@samples.scheduler_current_command).to eq :restart
    sleep 2
    expect(@samples.scheduler_current_command).to eq nil
    expect(@samples.scheduler_commands_list).to eq []

    sleep 1

    # only first process should be restarted
    expect(@p1.scheduler_last_command).to eq :restart
    expect(@p2.scheduler_last_command).to eq :monitor
  end

end
