require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Checker::Cputime" do

  subject do
    Eye::Checker.create(123, {:type => :cputime, :every => 5.seconds, :times => 1, :below => 10.minutes})
  end

  it "get_value" do
    expect(Eye::SystemResources).to receive(:cputime).with(123) { 65 }
    expect(subject.get_value).to eq 65
  end

  it "good" do
    allow(subject).to receive(:get_value) { 5.minutes }
    expect(subject.check).to eq true

    allow(subject).to receive(:get_value) { 20.minutes }
    expect(subject.check).to eq false
  end
end
