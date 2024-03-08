require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "ChildProcess" do

  describe "starting, monitoring" do
    after :each do
      @process.stop if @process
    end

    it "should monitoring when process has children and enable option" do
      cfg = C.p3.merge(:monitor_children => {})
      start_ok_process(cfg)
      sleep 5 # ensure that children are found

      expect(@process.state_name).to eq :up
      expect(@process.children.keys).not_to eq []
      expect(@process.children.keys.size).to eq 3
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]

      child = @process.children.values.first
      expect(child[:notify]).to eq({ "abcd" => :warn })
      expect(child.watchers.keys).to eq []
    end

    it "should not monitoring when process has children and disable option" do
      start_ok_process(C.p3)
      expect(@process.children).to eq({})
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity]
    end

    it "should not monitoring when process has no children and enable option" do
      start_ok_process(C.p1.merge(:monitor_children => {}))
      expect(@process.children).to eq({})
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]
    end

    it "when one child dies, should update list" do
      start_ok_process(C.p3.merge(:monitor_children => {}, :children_update_period => Eye::SystemResources::cache.expire + 1))
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]

      sleep 5 # ensure that children are found

      #p @process.children
      pids = @process.children.keys.sort

      # just one child dies
      died_pid = pids.sample
      die_process!(died_pid, 9)

      # sleep enought for update list
      sleep (Eye::SystemResources::cache.expire * 2 + 1).seconds

      new_pids = @process.children.keys.sort

      expect(pids).not_to eq new_pids
      expect(pids - new_pids).to eq [died_pid]
      expect((new_pids - pids).size).to eq 1
    end

    it "all children die, should update list" do
      start_ok_process(C.p3.merge(:monitor_children => {}, :children_update_period => Eye::SystemResources::cache.expire + 1))
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]

      sleep 5 # ensure that children are found

      #p @process.children
      master_pid = @process.pid
      pids = @process.children.keys.sort

      # one of the child is just die
      Eye::System.execute("kill -HUP #{master_pid}")

      # sleep enought for update list
      sleep (Eye::SystemResources::cache.expire * 2 + 2).seconds

      new_pids = @process.children.keys.sort

      expect(master_pid).to eq @process.pid
      expect(new_pids.size).to eq 3
      expect(pids - new_pids).to eq pids
      expect(new_pids - pids).to eq new_pids
    end

    it "when process stops, children are cleaned up" do
      start_ok_process(C.p3.merge(:monitor_children => {}, :children_update_period => Eye::SystemResources::cache.expire + 1))
      sleep 5 # ensure that children are found

      pid = @process.pid
      expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_children]
      expect(@process.children.size).to eq 3

      @process.stop
      sleep 2
      expect(@process.watchers.keys).to eq []
      expect(@process.children.size).to eq 0

      expect(Eye::System.pid_alive?(pid)).to eq false
    end

  end

  describe "add_or_update_children" do
    before :each do
      start_ok_process(C.p1.merge(:monitor_children => {}))
    end

    it "add new children, update && remove" do
      allow(Eye::SystemResources).to receive(:children).with(@process.pid){ [3,4,5] }
      @process.add_or_update_children
      expect(@process.children.keys.sort).to eq [3,4,5]

      allow(Eye::SystemResources).to receive(:children).with(@process.pid){ [3,5,6] }
      @process.add_or_update_children
      expect(@process.children.keys.sort).to eq [3,5,6]

      allow(Eye::SystemResources).to receive(:children).with(@process.pid){ [3,5] }
      @process.add_or_update_children
      expect(@process.children.keys.sort).to eq [3,5]

      allow(Eye::SystemResources).to receive(:children).with(@process.pid){ [6,7] }
      @process.add_or_update_children
      expect(@process.children.keys.sort).to eq [6,7]

      @process.remove_children
      expect(@process.children).to eq({})
    end
  end

end
