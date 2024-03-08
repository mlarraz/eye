require File.dirname(__FILE__) + '/spec_helper'

RSpec.describe "Eye::Utils" do
  it "human_time" do
    s = Eye::Utils.human_time(Time.now.to_i)
    expect(s.size).to eq 5
    expect(s).to include(':')

    s = Eye::Utils.human_time(1377978030)
    expect(s).to eq 'Aug31'
  end
end
