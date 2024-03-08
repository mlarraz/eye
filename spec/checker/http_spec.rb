require File.dirname(__FILE__) + '/../spec_helper'

def chhttp(cfg = {})
  Eye::Checker.create(nil, {:type => :http, :every => 5.seconds,
        :times => 1, :url => "http://localhost:3000/", :kind => :success,
        :pattern => /OK/, :timeout => 2}.merge(cfg))
end

describe "Eye::Checker::Http" do

  after :each do
    FakeWeb.clean_registry
  end

  describe "get_value" do
    subject{ chhttp }

    it "initialize" do
      expect(subject.instance_variable_get(:@kind)).to eq Net::HTTPSuccess
      expect(subject.instance_variable_get(:@open_timeout)).to eq 3
      expect(subject.instance_variable_get(:@read_timeout)).to eq 2
      expect(subject.pattern).to eq /OK/
    end

    it "correctly set http status" do
      expect(chhttp(:kind => 200).instance_variable_get(:@kind)).to eq Net::HTTPOK
    end

    it "without url" do
      expect{ chhttp(:url => nil).uri }.to raise_error
    end

    it "get_value" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      expect(subject.get_value[:result].body).to eq "Somebody OK"

      expect(subject.human_value(subject.get_value)).to eq "200=0Kb"
    end

    it "get_value exception" do
      a = ""
      allow(subject).to receive(:session) { a }
      allow(subject.session).to receive(:start) { raise Timeout::Error, "timeout" }
      mes = RUBY_VERSION < '2.0' ? "Timeout<3.0,2.0>" : "ReadTimeout<2.0>"

      expect(subject.get_value).to eq({:exception => mes})
      expect(subject.human_value(subject.get_value)).to eq mes
    end

    if defined?(Net::OpenTimeout)
      it "get_value OpenTimeout exception" do
        a = ""
        allow(subject).to receive(:session) { a }
        allow(subject.session).to receive(:start) { raise Net::OpenTimeout, "open timeout" }

        expect(subject.get_value).to eq({:exception => "OpenTimeout<3.0>"})
        expect(subject.human_value(subject.get_value)).to eq "OpenTimeout<3.0>"
      end
    end

    it "get_value raised" do
      a = ""
      allow(subject).to receive(:session) { a }
      allow(subject.session).to receive(:start) { raise "something" }
      expect(subject.get_value).to eq({:exception => "Error<something>"})

      expect(subject.human_value(subject.get_value)).to eq "Error<something>"
    end

  end

  describe "good?" do
    subject{ chhttp }

    it "good" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      expect(subject.check).to eq true
    end

    it "good pattern is string" do
      subject = chhttp(:pattern => "OK")
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      expect(subject.check).to eq true
    end

    it "bad pattern" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody bad")
      expect(subject.check).to eq false
    end

    it "bad pattern string" do
      subject = chhttp(:pattern => "OK")
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody bad")
      expect(subject.check).to eq false
    end

    it "not 200" do
      FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody OK", :status => [500, 'err'])
      expect(subject.check).to eq false
    end

    it "without patter its ok" do
      subject = chhttp(:pattern => nil)
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      expect(subject.check).to eq true
    end
  end

  describe "validates" do
    it "ok" do
      Eye::Checker.validate!({:type => :http, :every => 5.seconds,
        :times => 1, :url => "http://localhost:3000/", :kind => :success,
        :pattern => /OK/, :timeout => 2})
    end

    it "without param url" do
      expect{ Eye::Checker.validate!({:type => :http, :every => 5.seconds,
        :times => 1, :kind => :success,
        :pattern => /OK/, :timeout => 2}) }.to raise_error(Eye::Dsl::Validation::Error)
    end

    it "bad param timeout" do
      expect{ Eye::Checker.validate!({:type => :http, :every => 5.seconds,
        :times => 1, :kind => :success, :url => "http://localhost:3000/",
        :pattern => /OK/, :timeout => :fix}) }.to raise_error(Eye::Dsl::Validation::Error)
    end
  end

  describe "session" do
    subject { http_checker.send :session }

    context "when scheme is http" do
      let(:http_checker) { chhttp }

      it "does not use SSL" do
        expect(subject.use_ssl?).not_to eq true
      end
    end

    context "when scheme is https" do
      let(:http_checker) { chhttp(url: "https://google.com") }

      it "uses SSL" do
        expect(subject.use_ssl?).to eq true
      end

      it "sets veryfy_mode" do
        expect(subject.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
      end
    end

    context "when 'open_timeout' is given" do
      let(:http_checker) { chhttp(open_timeout: 42) }

      it "sets open_timout according to given value" do
        expect(subject.open_timeout).to eq(42)
      end
    end

    context "when 'open_timeout' is not given" do
      let(:http_checker) { chhttp(open_timeout: nil) }

      it "takes 3 seconds by default" do
        expect(subject.open_timeout).to eq(3)
      end
    end

    context "when 'read_timeout' is given" do
      let(:http_checker) { chhttp(read_timeout: 42) }

      it "sets read_timeout according to given value" do
        expect(subject.read_timeout).to eq(42)
      end
    end

    context "when 'timeout' is given" do
      let(:http_checker) { chhttp(timeout: 42) }

      it "sets read_timeout according to given value" do
        expect(subject.read_timeout).to eq(42)
      end
    end

    context "when neither 'read_timeout' nor 'timeout' is given" do
      let(:http_checker) { chhttp(read_timeout: nil, timeout: nil) }

      it "takes 15 secods by default" do
        expect(subject.read_timeout).to eq(15)
      end
    end

    context "when proxy is given" do
      let(:http_checker) { chhttp(proxy_url: 'http://localhost:1080') }

      it "sets proxy accoring to given value" do
        expect(subject.proxy_address).to eq('localhost')
        expect(subject.proxy_port).to eq(1080)
      end
    end
  end

end
