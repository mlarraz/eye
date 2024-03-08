require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Group" do

  describe "Chain calls" do

    it "should call chain_schedule for start" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:type => :async, :command => :start, :grace => 7}}})
      expect(@g).to receive(:chain_schedule).with(:async, 7, command: :start)
      @g.start
    end

    it "should call chain_schedule for start, with type sync" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:type => :sync, :command => :start, :grace => 7}}})
      expect(@g).to receive(:chain_schedule).with(:sync, 7, command: :start)
      @g.start
    end

    it "config for start and restart, use both" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:type => :async, :command => :start, :grace => 7}, :restart => {:type => :sync, :command => :restart, :grace => 8}}})
      expect(@g).to receive(:chain_schedule).with(:async, 7, command: :start)
      @g.start

      expect(@g).to receive(:chain_schedule).with(:sync, 8, command: :restart)
      @g.restart
    end

    it "should use options type" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:type => :sync, :command => :start}}})
      expect(@g).to receive(:chain_schedule).with(:sync, Eye::Group::DEFAULT_CHAIN, command: :start)
      @g.start
    end

    it "with empty grace, should call default grace 0" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:command => :start}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :start)
      @g.start
    end

    it "chain options for restart, but called start, should call chain but with default options" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:command => :restart}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "restart without grace, should call default grace 0" do
      @g = Eye::Group.new('gr', {:chain => {:restart => {:command => :restart}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "restart with invalid type, should call with async" do
      @g = Eye::Group.new('gr', {:chain => {:restart => {:command => :restart, :type => [12324]}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "restart with invalid grace, should call default grace 0" do
      @g = Eye::Group.new('gr', {:chain => {:restart => {:command => :restart, :grace => []}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "restart with invalid grace, should call default grace 0" do
      @g = Eye::Group.new('gr', {:chain => {:restart => {:command => :restart, :grace => :some_error}}})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "restart with empty config, should call chain_schedule" do
      @g = Eye::Group.new('gr', {})
      expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :restart)
      @g.restart
    end

    it "when chain clearing by force" do
      @g = Eye::Group.new('gr', {:chain => {:start => {:command => :start, :grace => 0}, :restart => {:command => :restart, :grace => 0}}})
      expect(@g).to receive(:chain_schedule).with(:async, 0, command: :monitor)
      @g.monitor

      expect(@g).to receive(:chain_schedule).with(:async, 0, command: :restart)
      @g.restart

      expect(@g).to receive(:chain_schedule).with(:async, 0, command: :start)
      @g.start
    end

    it "with params" do
      @g = Eye::Group.new('gr', {})
      expect(@g).to receive(:fast_call).with(:command => :signal, :args => [15])
      @g.signal(15)
    end

    describe "monitor using chain as start" do
      it "monitor call chain" do
        @g = Eye::Group.new('gr', {:chain => {:start => {:command => :start, :grace => 3}}})
        expect(@g).to receive(:chain_schedule).with(:async, 3, command: :monitor)
        @g.monitor
      end

      it "monitor not call chain" do
        @g = Eye::Group.new('gr', {:chain => {:restart => {:command => :restart, :grace => 3}}})
        expect(@g).to receive(:chain_schedule).with(:async, Eye::Group::DEFAULT_CHAIN, command: :monitor)
        @g.monitor
      end
    end
  end
end
