require File.dirname(__FILE__) + '/spec_helper'

[:old, :new].each do |prot_type|
  describe "Eye::Client, Eye::Server - #{prot_type}" do
    before :each do
      @socket_path = C.socket_path
      @client = Eye::Client.new(@socket_path, prot_type)
      @server = Eye::Server.new(@socket_path)

      @server.async.run
      sleep 0.1
    end

    after :each do
      @server.terminate
    end

    it "client command, should send to controller" do
      expect(Eye::Control).to receive(:command).with('restart', 'samples', {}){ :command_sent }
      expect(Eye::Control).to receive(:command).with(:stop, {}){ :command_sent2 }
      expect(@client.execute(command: 'restart', args: %w{samples})).to eq :command_sent
      expect(@client.execute(command: :stop)).to eq :command_sent2
    end

    it "another spec works too" do
      expect(Eye::Control).to receive(:command).with('stop', {}){ :command_sent2 }
      expect(@client.execute(command: 'stop')).to eq :command_sent2
    end

    it "if server already listen should recreate" do
      expect(Eye::Control).to receive(:command).with('stop', {}){ :command_sent2 }
      @server2 = Eye::Server.new(@socket_path)
      @server2.async.run
      sleep 0.1
      expect(@client.execute(command: 'stop')).to eq :command_sent2
    end

    it "if error server should be alive" do
      expect(@client.send(:attempt_command, 'trash', 1)).to eq :corrupted_data
      expect(@server.alive?).to eq true
    end

    if prot_type == :new
      it "big message, to pass env variables in future" do
        a = "a" * 10000
        expect(Eye::Control).to receive(:command).with('stop', a, {}){ :command_sent2 }
        expect(@client.execute(command: 'stop', args: [a])).to eq :command_sent2
      end
    end

    it "big message, to answer" do
      a = "a" * 50000
      expect(Eye::Control).to receive(:command).with('stop', {}){ a }
      expect(@client.execute(command: 'stop').size).to eq 50000
    end

    # TODO, remove in 1.0
    describe "old message format" do
      it "ok message" do
        expect(Eye::Control).to receive(:command).with('restart', 'samples', {}){ :command_sent }
        expect(@client.send(:attempt_command, Marshal.dump(%w{restart samples}), 1)).to eq :command_sent
      end
    end
  end
end
