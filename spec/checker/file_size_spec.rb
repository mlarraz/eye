require File.dirname(__FILE__) + '/../spec_helper'

def chfsize(cfg = {})
  Eye::Checker.create(nil, {:type => :fsize, :every => 5.seconds,
        :file => $logger_path, :times => 1}.merge(cfg))
end

describe "Eye::Checker::FileSize" do

  describe "" do
    subject{ chfsize }

    it "get_value" do
      expect(subject.get_value).to be_within(10).of(File.size($logger_path))
    end

    it "not good if size equal prevous" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq false
    end

    it "good when little different with previous" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1002}
      expect(subject.check).to eq true
    end
  end

  describe "below" do
    subject{ chfsize(:below => 10) }

    it "good" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1005}
      expect(subject.check).to eq true
    end

    it "bad" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1015}
      expect(subject.check).to eq false
    end

  end

  describe "above" do
    subject{ chfsize(:above => 10) }

    it "good" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1005}
      expect(subject.check).to eq false
    end

    it "bad" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1015}
      expect(subject.check).to eq true
    end

  end


  describe "above and below" do
    subject{ chfsize(:above => 10, :below => 30) }

    it "bad" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1005}
      expect(subject.check).to eq false
    end

    it "good" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1021}
      expect(subject.check).to eq true
    end

    it "bad" do
      allow(subject).to receive(:get_value) {1001}
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) {1045}
      expect(subject.check).to eq false
    end

  end


end
