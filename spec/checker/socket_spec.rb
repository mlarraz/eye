require File.dirname(__FILE__) + '/../spec_helper'

def chsock(cfg = {})
  Eye::Checker.create(nil, {:type => :socket, :every => 5.seconds,
        :times => 1, :addr => "tcp://127.0.0.1:#{C.p4_ports[0]}", :send_data => "ping",
        :expect_data => /pong/, :timeout => 2}.merge(cfg))
end

def chsockb(cfg = {})
  Eye::Checker.create(nil, {:type => :socket, :every => 5.seconds,
        :times => 1, :addr => "tcp://127.0.0.1:#{C.p4_ports[1]}", :protocol => :em_object, :send_data => {},
        :expect_data => /pong/, :timeout => 2}.merge(cfg))
end

def ssl_chsockb(cfg = {})
  Eye::Checker.create(nil, {:type => :ssl_socket, :every => 5.seconds,
        :times => 1, :addr => "tcp://127.0.0.1:#{C.p4_ports[2]}", :send_data => "bla",
        :expect_data => /bla:1/, :timeout => 2}.merge(cfg))
end

RSpec.describe "Socket Checker" do
  after :each do
    FileUtils.rm(C.p4_sock) rescue nil
  end

  ["tcp://127.0.0.1:#{C.p4_ports[0]}", "unix:#{C.p4_sock}"].each do |addr|
    describe "socket: '#{addr}'" do
      before :each do
        start_ok_process(C.p4)
      end

      it "good answer" do
        c = chsock(:addr => addr)
        expect(c.get_value).to eq({:result => 'pong'})
        expect(c.check).to eq true

        c = chsock(:addr => addr, :expect_data => "pong") # string result ok too
        expect(c.check).to eq true
      end

      it "timeouted" do
        c = chsock(:addr => addr, :send_data => "timeout")
        expect(c.get_value).to eq({:exception => "ReadTimeout<2.0>"})
        expect(c.check).to eq false
      end

      it "bad answer" do
        c = chsock(:addr => addr, :send_data => "bad")
        expect(c.get_value).to eq({:result => 'what'})
        expect(c.check).to eq false

        c = chsock(:addr => addr, :send_data => "bad", :expect_data => "pong") # string result bad too
        expect(c.check).to eq false
      end

      it "socket not found" do
        @process.stop
        c = chsock(:addr => addr + "111")
        if addr =~ /tcp/
          expect(c.get_value[:exception]).to include("Error<")
        else
          expect(c.get_value[:exception]).to include("No such file or directory")
        end
        expect(c.check).to eq false
      end

      it "check responding without send_data" do
        c = chsock(:addr => addr, :send_data => nil, :expect_data => nil)
        expect(c.get_value).to eq({:result => :listen})
        expect(c.check).to eq true
      end

      it "check responding without send_data" do
        c = chsock(:addr => addr + "111", :send_data => nil, :expect_data => nil)
        if addr =~ /tcp/
          expect(c.get_value[:exception]).to include("Error<")
        else
          expect(c.get_value[:exception]).to include("No such file or directory")
        end
        expect(c.check).to eq false
      end
    end

    describe "raw protocol '#{addr}'" do
      before :each do
        start_ok_process(C.p4)
      end

      it "good answer" do
        c = chsock(:addr => addr, :send_data => 'raw', :expect_data => "raw_ans", :timeout => 0.5, :protocol => :raw)
        expect(c.get_value).to eq({:result => 'raw_ans'})
        expect(c.check).to eq true
      end

      it "timeout when using without :raw" do
        c = chsock(:addr => addr, :send_data => 'raw', :expect_data => "raw_ans", :timeout => 0.5)
        expect(c.get_value).to eq({:exception => "ReadTimeout<0.5>"})
        expect(c.check).to eq false
      end
    end
  end

  describe "em object protocol" do
    before :each do
      start_ok_process(C.p4)
    end

    it "good answer" do
      c = chsockb(:send_data => {:command => 'ping'}, :expect_data => 'pong')
      expect(c.get_value).to eq({:result => 'pong'})
      expect(c.check).to eq true

      c = chsockb(:send_data => {:command => 'ping'}, :expect_data => /pong/)
      expect(c.check).to eq true

      c = chsockb(:send_data => {:command => 'ping'}, :expect_data => lambda{|r| r == 'pong'})
      expect(c.check).to eq true
    end

    it "should correctly get big message" do
      c = chsockb(:send_data => {:command => 'big'})
      res = c.get_value[:result]
      expect(res.size).to eq 9_999_999
    end

    it "when raised in proc, good? == false" do
      c = chsockb(:send_data => {:command => 'ping'}, :expect_data => lambda{|r| raise 'haha'})
      expect(c.check).to eq false
    end

    it "bad answer" do
      c = chsockb(:send_data => {:command => 'bad'}, :expect_data => 'pong')
      expect(c.get_value).to eq({:result => 'what'})
      expect(c.check).to eq false

      c = chsockb(:send_data => {:command => 'bad'}, :expect_data => /pong/)
      expect(c.check).to eq false

      c = chsockb(:send_data => {:command => 'bad'}, :expect_data => lambda{|r| r == 'pong'})
      expect(c.check).to eq false
    end
  end

  describe "ssl socket" do
    before :each do
      start_ok_process(C.p4)
    end

    it "should just work" do
      c = ssl_chsockb
      expect(c.get_value).to eq({:result => 'bla:1'})
      expect(c.check).to eq true
    end
  end
end
