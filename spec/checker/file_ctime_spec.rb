require File.dirname(__FILE__) + '/../spec_helper'

def chctime(cfg = {})
  Eye::Checker.create(nil, {:type => :ctime, :every => 5.seconds,
        :file => $logger_path, :times => 1}.merge(cfg))
end

describe "Eye::Checker::FileCTime" do

  describe "" do
    subject{ chctime }

    it "get_value" do
      expect(subject.get_value).to eq File.ctime($logger_path)
    end

    it "not good if size equal prevous" do
      allow(subject).to receive(:get_value) { Time.parse('00:00:01') }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { Time.parse('00:00:01') }
      expect(subject.check).to eq false
    end

    it "good when little different with previous" do
      allow(subject).to receive(:get_value) { Time.parse('00:00:01') }
      expect(subject.check).to eq true

      allow(subject).to receive(:get_value) { Time.parse('00:00:02') }
      expect(subject.check).to eq true
    end
  end

end
