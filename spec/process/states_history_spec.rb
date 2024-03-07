require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Process::StatesHistory" do
  before :each do
    @h = Eye::Process::StatesHistory.new
  end

  it "should work" do
    @h << :up
    @h.push :down, 'bla'

    expect(@h.states).to eq [:up, :down]
    expect(@h.last_state).to eq :down
    expect(@h.last_state_changed_at).to be_within(2.seconds).of(Time.now)
    expect(@h.last[:reason]).to eq 'bla'
  end

  it "states for period" do
    @h.push :up,    nil, 5.minutes.ago
    @h.push :down,  nil, 4.minutes.ago
    @h.push :start, nil, 3.minutes.ago
    @h.push :stop,  nil, 2.minutes.ago
    @h.push :up,    nil, 1.minutes.ago
    @h.push :down,  nil, 0.minutes.ago

    expect(@h.states_for_period(1.5.minutes)).to eq [:up, :down]
    expect(@h.states_for_period(2.5.minutes)).to eq [:stop, :up, :down]
    expect(@h.states_for_period(6.minutes)).to eq [:up, :down, :start, :stop, :up, :down]

    # with start_point
    expect(@h.states_for_period(2.5.minutes, 5.minutes.ago)).to eq [:stop, :up, :down]
    expect(@h.states_for_period(2.5.minutes, nil)).to eq [:stop, :up, :down]
    expect(@h.states_for_period(2.5.minutes, 1.5.minutes.ago)).to eq [:up, :down]
    expect(@h.states_for_period(2.5.minutes, Time.now)).to eq []
  end
end
