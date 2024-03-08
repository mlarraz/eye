require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Some crazy situations on load config" do

  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration.erb"))
    end
  end

  after :each do
    stop_controller

    File.delete(File.join(C.sample_dir, "lock1.lock")) rescue nil
    File.delete(File.join(C.sample_dir, "lock2.lock")) rescue nil
  end

  it "load another config, with same processes but changed names" do
    @controller.load_erb(fixture("dsl/integration2.erb"))

    sleep 10

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

    expect(@p1_.pid).to eq @old_pid1
    expect(@p2_.pid).to eq @old_pid2
    expect(@p3_.pid).to eq @old_pid3

    expect(@p1_.state_name).to eq :up
  end

end
