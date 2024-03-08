require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Checker::FileTouched" do

  subject do
    Eye::Checker.create(123, {:type => :file_touched, :every => 5.seconds, :times => 1, :file => "1"})
  end

  it "get_value" do
    expect(File).to receive(:exist?).with("1") { true }
    expect(subject.get_value).to eq true

    expect(File).to receive(:exist?).with("1") { false }
    expect(subject.get_value).to eq false
  end

  it "good" do
    expect(File).to receive(:exist?).with("1") { true }
    expect(subject.check).to eq false

    expect(File).to receive(:exist?).with("1") { false }
    expect(subject.check).to eq true
  end
end
