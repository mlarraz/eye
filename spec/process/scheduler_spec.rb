require File.dirname(__FILE__) + '/../spec_helper'

class Eye::Process
  attr_reader :test1, :test2, :test3, :test1_call

  def scheduler_test1(a)
    sleep 0.3
    @test1_call ||= 0
    @test1_call += 1
    @test1 = a
  end

  def scheduler_test2(a, b)
    sleep 0.6
    @test2 = [a, b]
  end

  def scheduler_test3(*args)
    @test3 = args
  end

  attr_reader :m

  def a(tm = 0.1)
    @m ||= []
    @m << :a
    sleep tm
  end

  def b(tm = 0.1)
    @m ||= []
    @m << :b
    sleep tm
  end

  def cu(tm = 0.1)
    @m ||= []
    @m << :cu
    sleep tm
  end

end

RSpec.describe "Scheduler" do
  before :each do
    @process = process C.p1
  end

  it "should schedule action" do
    expect(@process.test1).to eq nil
    @process.schedule :scheduler_test1, 1
    sleep 0.1
    expect(@process.scheduler_current_command).to eq :scheduler_test1
    expect(@process.test1).to eq nil
    sleep 0.4
    expect(@process.test1).to eq 1
    expect(@process.scheduler_current_command).to eq nil
  end

  it "should one after another" do
    expect(@process.test1).to eq nil
    expect(@process.test2).to eq nil

    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test2, 1, 2

    sleep 0.4
    expect(@process.test1).to eq 1
    expect(@process.test2).to eq nil

    sleep 0.6
    expect(@process.test1).to eq 1
    expect(@process.test2).to eq [1, 2]
  end

  it "should one after another2" do
    expect(@process.test1).to eq nil
    expect(@process.test2).to eq nil

    @process.schedule :scheduler_test2, 1, 2
    @process.schedule :scheduler_test1, 1

    sleep 0.4
    expect(@process.test1).to eq nil
    expect(@process.test2).to eq nil

    sleep 0.3
    expect(@process.test1).to eq nil
    expect(@process.test2).to eq [1, 2]

    sleep 0.3
    expect(@process.test1).to eq 1
    expect(@process.test2).to eq [1, 2]
  end

  it "should not scheduler duplicates" do
    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test1, 1

    sleep 1
    expect(@process.test1_call).to eq 1
  end

  it "should not scheduler duplicates for user schedules" do
    @process.user_schedule :command => :scheduler_test1, :args => [1]
    @process.user_schedule :command => :scheduler_test1, :args => [1]
    @process.user_schedule :command => :scheduler_test1, :args => [1]

    sleep 1
    expect(@process.test1_call).to eq 2
  end

  it "should scheduler duplicates by with different params" do
    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test1, 2
    @process.schedule :scheduler_test1, 3

    sleep 1
    expect(@process.test1_call).to eq 3
  end

  it "should terminate when actor die" do
    expect(@process.alive?).to eq true
    @process.terminate
    expect(@process.alive?).to eq false
  end

  it "should terminate even with tasks" do
    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test1, 1
    @process.schedule :scheduler_test1, 1

    @process.terminate
  end

  it "when scheduling terminate of the parent actor" do
    @process.schedule :terminate
    @process.schedule(:scheduler_test1, 1) rescue nil

    sleep 0.4
    expect(@process.alive?).to eq false
  end

  it "schedule unexisted method should not raise and break anything" do
    @process.schedule :hahhaha
    sleep 0.2
    expect(@process.alive?).to eq true
  end

  describe "reasons" do
    it "1 param without reason" do
      @process.schedule :scheduler_test3, 1
      sleep 0.1
      expect(@process.scheduler_last_command).to eq :scheduler_test3
      expect(@process.scheduler_last_reason).to eq nil
      expect(@process.test3).to eq [1]
    end

    it "1 param with reason" do
      @process.schedule command: :scheduler_test3, args: [1], reason: "reason"
      sleep 0.1
      expect(@process.scheduler_last_command).to eq :scheduler_test3
      expect(@process.scheduler_last_reason).to eq 'reason'
      expect(@process.test3).to eq [1]
    end

    it "many params with reason" do
      @process.schedule command: :scheduler_test3, args: [1, :bla, 3], reason: "reason"
      sleep 0.1
      expect(@process.scheduler_last_command).to eq :scheduler_test3
      expect(@process.scheduler_last_reason).to eq 'reason'
      expect(@process.test3).to eq [1, :bla, 3]
    end

    it "save history" do
      @process.schedule command: :scheduler_test3, args: [1, :bla, 3], reason: "reason"
      sleep 0.1
      h = @process.scheduler_history
      expect(h.size).to eq 1
      h = h[0]
      expect(h[:state]).to eq :scheduler_test3
      expect(h[:reason].to_s).to eq "reason"
    end
  end

  describe "signals" do
    it "work" do
      should_spend(0.3) do
        c1 = Celluloid::Condition.new
        @process.schedule command: :scheduler_test1, args: [1], reason: "reason", signal: c1
        c1.wait
      end
      expect(@process.test1).to eq 1
    end

    it "work with combinations" do
      should_spend(0.9) do
        c1 = Celluloid::Condition.new
        c2 = Celluloid::Condition.new
        @process.schedule command: :scheduler_test1, args: [1], reason: "reason", signal: c1
        @process.schedule command: :scheduler_test2, args: [1, 2], reason: "reason", signal: c2
        c1.wait
        c2.wait
      end
      expect(@process.test1).to eq 1
      expect(@process.test2).to eq [1, 2]
    end
  end

  describe "schedule_in" do
    it "should schedule to future" do
      @process.schedule(in: 1.second, command: :scheduler_test3, args: [1, 2, 3])
      sleep 0.5
      expect(@process.test3).to eq nil
      sleep 0.7
      expect(@process.test3).to eq [1,2,3]
    end
  end

  describe "when scheduler_freeze not accept new commands" do
    it "should schedule to future" do
      @process.schedule(:command => :scheduler_test3, :args => [1, 2, 3], :freeze => true)
      sleep 0.01
      expect(@process.test3).to eq [1, 2, 3]

      @process.schedule(:command => :scheduler_test3, :args => [5])
      @process.schedule(:command => :scheduler_test3, :args => [6])
      sleep 0.1
      expect(@process.test3).to eq [1, 2, 3]

      @process.schedule(:command => :scheduler_test3, :args => [7], :freeze => false)
      sleep 0.1
      expect(@process.test3).to eq [7]
    end
  end

  describe "schedule block" do
    it "schedule block" do
      @process.schedule(command: :instance_exec, block: -> { @test3 = [1, 2] })
      sleep 0.1
      expect(@process.test3).to eq [1, 2]
    end

    it "not crashing on exception" do
      @process.schedule(command: :instance_exec, block: -> { 1 + "bla" })
      sleep 0.1
      expect(@process.alive?).to be_true
    end
  end

  describe "Calls test" do
    before :each do
      @t = @process
    end

    it "should chain" do
      @t.scheduler_add command: :a, args: [0.5]
      @t.scheduler_add command: :b, args: [0.3]
      @t.scheduler_add command: :cu, args: [0.1]

      sleep 1

      expect(@t.m).to eq [:a, :b, :cu]
    end

    it "should chain2" do
      @t.scheduler_add command: :cu, args: [0.1]
      sleep 0.2

      @t.scheduler_add command: :a, args: [0.5]
      @t.scheduler_add command: :b, args: [0.3]

      sleep 1

      expect(@t.m).to eq [:cu, :a, :b]
    end

    it "#clear_pending_list" do
      10.times{ @t.scheduler_add command: :a }
      sleep 0.5
      @t.scheduler_clear_pending_list
      sleep 0.5
      expect(@t.m.size).to be <= 6
    end
  end
end
