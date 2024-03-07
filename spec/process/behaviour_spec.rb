require File.dirname(__FILE__) + '/../spec_helper'

describe "Behaviour" do
  before :each do
    @process = process C.p1
  end

  describe "sync with signals" do
    it "restart process with signal" do
      should_spend(2.5, 0.3) do
        c = Celluloid::Condition.new
        @process.send_call(:command => :start, :signal => c)
        c.wait
      end

      should_spend(3.0, 0.3) do
        c = Celluloid::Condition.new
        @process.send_call(:command => :restart, :signal => c)
        c.wait
      end

      expect(@process.state_name).to eq :up
      expect(@process.states_history.states).to eq [:unmonitored, :starting, :up, :restarting, :stopping, :down, :starting, :up]
    end
  end
end
