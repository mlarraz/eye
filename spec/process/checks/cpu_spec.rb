require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Process Cpu check" do

  before :each do
    @c = C.p1.merge(
      :checks => C.check_cpu
    )
  end

  it "should start periodical watcher" do
    start_ok_process(@c)

    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_cpu]

    @process.stop

    # after process stop should remove watcher
    expect(@process.watchers.keys).to eq []
  end

  describe "1 times" do
    before :each do
      @check = {:cpu => {:type => :cpu, :every => 2, :below => 10, :times => 1}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 3

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 20 }
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 1
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 3

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 7 }
      expect(@process).not_to receive(:schedule).with({ :command => :restart })

      sleep 1
    end
  end

  describe "3 times" do
    before :each do
      @check = {:cpu => {:type => :cpu, :every => 2, :below => 10, :times => 3}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 3

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 15 }
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 6
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 3

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 7 }
      expect(@process).not_to receive(:schedule).with({ :command => :restart })

      sleep 6
    end
  end

  describe "3 times" do
    before :each do
      @check = {:cpu => {:type => :cpu, :every => 2, :below => 10, :times => [3,5]}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 5

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 15 }
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 6
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 5 }

      sleep 5

      allow(Eye::SystemResources).to receive(:cpu).with(@process.pid){ 7 }
      expect(@process).not_to receive(:schedule).with({ :command => :restart })

      sleep 6
    end
  end

end
