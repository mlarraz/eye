require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "ChildProcess" do

  describe "starting, monitoring" do
    after :each do
      @process.stop if @process
    end

    it "should just monitoring, and do nothin" do
      start_ok_process(C.p3.merge(:monitor_children => {:checks => join(C.check_mem, C.check_cpu)}))
      sleep 6

      expect(@process.state_name).to eq :up
      expect(@process.children.keys).not_to eq []
      expect(@process.children.keys.size).to eq 3
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]

      @children = @process.children.values
      @children.each do |child|
        expect(child.watchers.keys).to eq [:check_memory, :check_cpu]
        expect(child).not_to receive(:schedule).with(:restart)
      end

      sleep 7
    end

    it "should check children even when one of them respawned" do
      start_ok_process(C.p3.merge(:monitor_children => {:checks => join(C.check_mem, C.check_cpu)}, :children_update_period => Eye::SystemResources::cache.expire + 1))
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]

      sleep 6 # ensure that children are found

      expect(@process.children.size).to eq 3

      # now restarting
      died = @process.children.keys.sample
      die_process!(died, 9)

      # sleep enought for update list
      sleep (Eye::SystemResources::cache.expire * 2 + 3).seconds

      expect(@process.children.size).to eq 3
      expect(@process.children.keys).not_to include(died)

      @children = @process.children.values
      @children.each do |child|
        expect(child.watchers.keys).to eq [:check_memory, :check_cpu]
        expect(child).not_to receive(:schedule).with(:restart)
      end
    end

    it "some child get condition" do
      start_ok_process(C.p3.merge(:monitor_children => {:checks =>
        join(C.check_mem, C.check_cpu(:below => 50, :times => 2))}))
      sleep 6

      expect(@process.children.size).to eq 3

      @children = @process.children.values
      crazy = @children.shift

      @children.each do |child|
        expect(child.watchers.keys).to eq [:check_memory, :check_cpu]
        expect(child).not_to receive(:schedule).with(:command => :restart)
      end

      allow(Eye::SystemResources).to receive(:cpu).with(crazy.pid){ 55 }
      allow(Eye::SystemResources).to receive(:cpu).with(anything){ 5 }

      expect(crazy.watchers.keys).to eq [:check_memory, :check_cpu]
      expect(crazy).to receive(:notify).with(:warn, "Bounded cpu(<50%): [*55%, *55%] send to [:restart]")
      expect(crazy).to receive(:schedule).with(:command => :restart)

      sleep 4
      crazy.remove_watchers # for safe end spec
    end
  end
end
