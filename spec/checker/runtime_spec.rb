require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Checker::Runtime" do

  subject do
    Eye::Checker.create(123, {:type => :runtime, :every => 5.seconds, :times => 1, :below => 10.minutes})
  end

  it "get_value" do
    allow(Eye::SystemResources).to receive(:start_time).with(123) { 65 }
    expect(subject.get_value).to eq Time.now.to_i - 65
  end

  it "good" do
    allow(subject).to receive(:get_value) { 5.minutes }
    expect(subject.check).to eq true

    allow(subject).to receive(:get_value) { 20.minutes }
    expect(subject.check).to eq false
  end
end
