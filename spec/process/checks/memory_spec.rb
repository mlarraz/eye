require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Process Memory check" do

  before :each do
    @c = C.p1.merge(
      :checks => C.check_mem
    )
  end

  it "should start periodical watcher" do
    start_ok_process(@c)

    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_memory]

    @process.stop

    # after process stop should remove watcher
    expect(@process.watchers.keys).to eq []
  end

  describe "1 times" do
    before :each do
      @check = {:memory => {:every => 2, :below => 40.megabytes, :times => 1, :type => :memory}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }

      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 50.megabytes }
      expect(@process.wrapped_object).to receive(:notify).with(:warn, anything)
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 1
    end

    it "when memory exceed limit process should stop if fires :stop" do
      @check = {:memory => {:every => 2, :below => 40.megabytes, :times => 1, :type => :memory, :fires => :stop}}
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }

      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 50.megabytes }
      expect(@process.wrapped_object).to receive(:notify).with(:warn, anything)
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :stop })

      sleep 1
    end

    it "when memory exceed limit process should stop if fires [:stop, :start]" do
      @check = {:memory => {:every => 2, :below => 40.megabytes, :times => 1, :type => :memory, :fires => [:stop, :start]}}
      start_ok_process(@c.merge(:checks => @check))
      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }

      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 50.megabytes }
      expect(@process.wrapped_object).to receive(:notify).with(:warn, anything)
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :stop })
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :start })

      sleep 1
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }
      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 25.megabytes }
      expect(@process.wrapped_object).not_to receive(:schedule).with({ :command => :restart })

      sleep 1
    end
  end

  describe "3 times" do
    before :each do
      @check = {:memory => {:every => 2, :below => 40.megabytes, :times => 3, :type => :memory}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }
      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 50.megabytes }
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 6
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }
      sleep 3

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 25.megabytes }
      expect(@process.wrapped_object).not_to receive(:schedule).with({ :command => :restart })

      sleep 6
    end
  end

  describe "3,5 times" do
    before :each do
      @check = {:memory => {:every => 2, :below => 40.megabytes, :times => [3,5], :type => :memory}}
    end

    it "when memory exceed limit process should restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }
      sleep 5

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 50.megabytes }
      expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })

      sleep 6
    end

    it "else should not restart" do
      start_ok_process(@c.merge(:checks => @check))

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 20.megabytes }
      sleep 5

      allow(Eye::SystemResources).to receive(:memory).with(@process.pid){ 25.megabytes }
      expect(@process.wrapped_object).not_to receive(:schedule).with({ :command => :restart })

      sleep 6
    end
  end

end
