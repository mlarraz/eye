require File.dirname(__FILE__) + '/../spec_helper'

def chmem(cfg = {})
  Eye::Checker.create(123, {:type => :memory, :every => 5.seconds,
        :times => 1}.merge(cfg))
end

describe "Eye::Checker::Memory" do

  describe "without below" do
    subject{ chmem }

    it "get_value" do
      expect(Eye::SystemResources).to receive(:memory).with(123) { 66560 }
      expect(subject.get_value).to eq 66560
    end

    it "without below always true" do
      allow(subject).to receive(:get_value) { 315 }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 320 }
      expect(subject.check).to eq true
    end
  end

  describe "with below" do
    subject{ chmem(:below => 300.megabytes) }

    it "good" do
      allow(subject).to receive(:get_value) { 200.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 250.megabytes }
      expect(subject.check).to eq true
    end

    it "good" do
      allow(subject).to receive(:get_value) { 250.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 350.megabytes }
      expect(subject.check).to eq false
    end

  end

  describe "with above" do
    subject{ chmem(:above => 300.megabytes) }

    it "good" do
      allow(subject).to receive(:get_value) { 400.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 450.megabytes }
      expect(subject.check).to eq true
    end

    it "good and bad" do
      allow(subject).to receive(:get_value) { 450.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 250.megabytes }
      expect(subject.check).to eq false
    end
  end

  describe "with above and below" do
    subject{ chmem(:above => 300.megabytes, :below => 500.megabytes) }

    it "good" do
      allow(subject).to receive(:get_value) { 400.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 450.megabytes }
      expect(subject.check).to eq true
    end

    it "good and bad" do
      allow(subject).to receive(:get_value) { 450.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 250.megabytes }
      expect(subject.check).to eq false

      allow(subject).to receive(:get_value) { 400.megabytes }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { 550.megabytes }
      expect(subject.check).to eq false
    end
  end

  describe "with above and below incorrect" do
    subject{ chmem(:above => 500.megabytes, :below => 100.megabytes) }

    it "always bad" do
      allow(subject).to receive(:get_value) { 400.megabytes }
      expect(subject.check).to eq false

      allow(subject).to receive(:get_value) { 50.megabytes }
      expect(subject.check).to eq false

      allow(subject).to receive(:get_value) { 600.megabytes }
      expect(subject.check).to eq false
    end
  end

  describe "validates" do
    it "ok" do
      Eye::Checker.validate!({:type => :memory, :every => 5.seconds, :times => 1, :below => 10.0.bytes})
    end

    it "bad param below" do
      expect{ Eye::Checker.validate!({:type => :memory, :every => 5.seconds, :times => 1, :below => {1 => 2}}) }.to raise_error(Eye::Dsl::Validation::Error)
    end

    it "unknown params" do
      expect{ Eye::Checker.validate!({:hello => true, :type => :memory, :every => 5.seconds, :times => 1, :below => 10.0.bytes})}.to raise_error(Eye::Dsl::Validation::Error)
    end

  end


end
