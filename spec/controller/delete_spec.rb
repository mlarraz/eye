require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Intergration Delete" do
  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration.erb"))
    end
  end

  after :each do
    stop_controller
  end

  it "delete group not monitoring anymore" do
    expect(@controller.command(:delete, "samples")).to eq({:result => ["int:samples"]})
    sleep 7 # while

    expect(@controller.all_processes).to eq [@p3]
    expect(@controller.all_groups.map(&:name)).to eq ['__default__']

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    Eye::System.send_signal(@old_pid1)
    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false

    # noone up this
    sleep 2
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
  end

  it "delete process not monitoring anymore" do
    @controller.command(:delete, "sample1")
    sleep 7 # while

    expect(@controller.all_processes.map(&:name).sort).to eq %w{forking sample2}
    expect(@controller.all_groups.map(&:name).sort).to eq %w{__default__ samples}
    expect(@controller.group_by_name('samples').processes.full_size).to eq 1
    expect(@controller.group_by_name('samples').processes.map(&:name)).to eq %w{sample2}

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    Eye::System.send_signal(@old_pid1)
    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
  end

  it "delete application" do
    @p3.wait_for_condition(15, 0.3) { @p3.children.size == 3 }
    @pids += @p3.children.keys

    @controller.command(:delete, "int")
    sleep 7 # while

    expect(@controller.all_processes).to eq []
    expect(@controller.all_groups).to eq []
    expect(@controller.applications).to eq []

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    Eye::System.send_signal(@old_pid1)
    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false

    actors = Celluloid::Actor.all.map(&:class)
    expect(actors).not_to include(Eye::Process)
    expect(actors).not_to include(Eye::Group)
    expect(actors).not_to include(Eye::Application)
    expect(actors).not_to include(Eye::Checker::Memory)
  end

  it "delete by mask" do
    expect(@controller.command(:delete, "sam*")).to eq({:result => ["int:samples"]})
    sleep 7 # while

    expect(@controller.all_processes).to eq [@p3]
    expect(@controller.all_groups.map(&:name)).to eq ['__default__']

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    Eye::System.send_signal(@old_pid1)
    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false

    # noone up this
    sleep 2
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
  end

end
