require File.dirname(__FILE__) + '/../spec_helper'

describe "StopOnDelete behaviour" do
  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration_sor.erb"))
    end
  end

  after :each do
    stop_controller
  end

  it "delete process => stop process" do
    @controller.command(:delete, "sample1")
    sleep 7 # while

    expect(@controller.all_processes.map(&:name).sort).to eq %w{forking sample2}
    expect(@controller.all_groups.map(&:name).sort).to eq %w{__default__ samples}

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
  end

  it "delete application => stop group proceses" do
    expect(@controller.command(:delete, "samples")).to eq({:result => ["int:samples"]})
    sleep 7 # while

    expect(@controller.all_processes).to eq [@p3]
    expect(@controller.all_groups.map(&:name)).to eq ['__default__']

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq false
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    sleep 0.5
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false

    # noone up this
    sleep 2
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
  end

  it "delete application => stop all proceses" do
    @controller.command(:delete, "int")
    sleep 8 # while

    expect(@controller.all_processes).to eq []
    expect(@controller.all_groups).to eq []
    expect(@controller.applications).to eq []

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq false
    expect(Eye::System.pid_alive?(@old_pid3)).to eq false

    sleep 1
    expect(Eye::System.pid_alive?(@old_pid1)).to eq false

    actors = Celluloid::Actor.all.map(&:class)
    expect(actors).not_to include(Eye::Process)
    expect(actors).not_to include(Eye::Group)
    expect(actors).not_to include(Eye::Application)
    expect(actors).not_to include(Eye::Checker::Memory)
  end

  it "load config when 1 process deleted, it should stopped" do
    @controller.load_erb(fixture("dsl/integration_sor2.erb"))

    sleep 10

    procs = @controller.all_processes
    @p1_ = procs.detect{|c| c.name == 'sample1'}
    @p2_ = procs.detect{|c| c.name == 'sample2'}
    @p3_ = procs.detect{|c| c.name == 'sample3'}

    expect(@p1_.object_id).to eq @p1.object_id
    expect(@p2_.object_id).to eq @p2.object_id
    expect(@p3_.state_name).to eq :up

    expect(@p1_.pid).to eq @old_pid1
    expect(@p2_.pid).to eq @old_pid2

    expect(Eye::System.pid_alive?(@old_pid1)).to eq true
    expect(Eye::System.pid_alive?(@old_pid2)).to eq true
    expect(Eye::System.pid_alive?(@old_pid3)).to eq false

    expect(@p3.alive?).to eq false
    expect(@controller.all_processes.map(&:name).sort).to eq %w{sample1 sample2 sample3}
  end

  it "load another config, with same processes but changed names" do
    @controller.load_erb(fixture("dsl/integration_sor3.erb"))

    sleep 15

    # @p1, @p2 recreates
    # @p3 the same

    procs = @controller.all_processes
    @p1_ = procs.detect{|c| c.name == 'sample1_'}
    @p2_ = procs.detect{|c| c.name == 'sample2_'}
    @p3_ = procs.detect{|c| c.name == 'forking'}

    expect(@p3.object_id).to eq @p3_.object_id
    expect(@p1.alive?).to eq false
    expect(@p1_.alive?).to eq true

    expect(@p2.alive?).to eq false
    expect(@p2_.alive?).to eq true

    expect(@p1_.pid).not_to eq @old_pid1
    expect(@p2_.pid).not_to eq @old_pid2
    expect(@p3_.pid).to eq @old_pid3

    expect(@p1_.state_name).to eq :up
    expect(@p2_.state_name).to eq :up
    expect(@p3_.state_name).to eq :up

    expect(Eye::System.pid_alive?(@old_pid1)).to eq false
    expect(Eye::System.pid_alive?(@old_pid2)).to eq false
    expect(Eye::System.pid_alive?(@old_pid3)).to eq true

    expect(Eye::System.pid_alive?(@p1_.pid)).to eq true
    expect(Eye::System.pid_alive?(@p2_.pid)).to eq true
  end

end
