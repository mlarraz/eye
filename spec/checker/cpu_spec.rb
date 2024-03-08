require File.dirname(__FILE__) + '/../spec_helper'

def chcpu(cfg = {})
  Eye::Checker.create(123, {:type => :cpu, :every => 5.seconds,
        :times => 1}.merge(cfg))
end

RSpec.describe "Eye::Checker::Cpu" do

  describe "without below" do
    subject{ chcpu }

    it "get_value" do
      expect(Eye::SystemResources).to receive(:cpu).with(123) { 65 }
      expect(subject.get_value).to eq 65
    end

    it "without below always true" do
      allow(subject).to receive(:get_value) { 15 }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 20 }
      expect(subject.check).to eq true
    end
  end

  describe "with below" do
    subject{ chcpu(:below => 30) }

    it "good" do
      allow(subject).to receive(:get_value) { 20 }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 25 }
      expect(subject.check).to eq true
    end

    it "good" do
      allow(subject).to receive(:get_value) { 25 }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 35 }
      expect(subject.check).to eq false
    end

  end

  describe "validates" do
    it "ok" do
      Eye::Checker.validate!({:type => :cpu, :every => 5.seconds, :times => 1, :below => 100})
    end

    it "bad param below" do
      expect {
        Eye::Checker.validate!({:type => :cpu, :every => 5.seconds, :times => 1, :below => {1 => 2}})
      }.to raise_error(Eye::Dsl::Validation::Error)
    end
  end
end
