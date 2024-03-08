require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Process::System" do
  before :each do
    @process = Eye::Process.new(C.p1)
  end

  it "load_pid_from_file" do
    File.open(@process[:pid_file_ex], 'w'){|f| f.write("asdf") }
    expect(@process.load_pid_from_file).to eq 0

    File.open(@process[:pid_file_ex], 'w'){|f| f.write(12345) }
    expect(@process.load_pid_from_file).to eq 12345

    FileUtils.rm(@process[:pid_file_ex]) rescue nil
    expect(@process.load_pid_from_file).to eq nil
  end

  it "failsafe_load_pid" do
    File.open(@process[:pid_file_ex], 'w'){|f| f.write("asdf") }
    expect(@process.failsafe_load_pid).to eq nil

    File.open(@process[:pid_file_ex], 'w'){|f| f.write(12345) }
    expect(@process.failsafe_load_pid).to eq 12345

    FileUtils.rm(@process[:pid_file_ex]) rescue nil
    expect(@process.failsafe_load_pid).to eq nil
  end

  it "load_external_pid_file" do
    expect(@process.send(:load_external_pid_file)).to eq :no_pid_file

    File.open(@process[:pid_file_ex], 'w'){|f| f.write(123455) }
    expect(@process.send(:load_external_pid_file)).to eq :not_running
    expect(@process.pid).to eq nil

    @pid = Eye::System.daemonize("ruby sample.rb", :working_dir => C.p1[:working_dir])[:pid]

    File.open(@process[:pid_file_ex], 'w'){|f| f.write(@pid) }
    expect(@process.send(:load_external_pid_file)).to eq :ok
    expect(@process.pid).to eq @pid

    @process.pid = nil
  end

  it "save_pid_to_file" do
    @process.pid = 123456789
    @process.save_pid_to_file
    expect(File.read(@process[:pid_file_ex]).to_i).to eq 123456789
  end

  it "failsafe_save_pid ok case" do
    @process.pid = 123456789
    expect(@process.failsafe_save_pid).to eq true
    expect(File.read(@process[:pid_file_ex]).to_i).to eq 123456789
  end

  it "failsafe_save_pid bad case" do
    @process.config[:pid_file_ex] = "/asdf/adf/asd/fs/dfs/das/df.1"
    @process.pid = 123456789
    expect(@process.failsafe_save_pid).to eq false
  end

  it "clear_pid_file" do
    @process.pid = 123456789
    @process.save_pid_to_file
    expect(File.read(@process[:pid_file_ex]).to_i).to eq 123456789

    expect(@process.clear_pid_file).to eq true
    expect(File.exist?(@process[:pid_file_ex])).to eq false
  end

  it "process_really_running?" do
    @process.pid = $$
    expect(@process.process_really_running?).to eq true

    @process.pid = nil
    expect(@process.process_really_running?).to eq nil

    @process.pid = -123434
    expect(@process.process_really_running?).to eq false
  end

  it "send_signal ok" do
    expect(Eye::System).to receive(:send_signal).with(@process.pid, :TERM){ {:result => :ok} }
    expect(@process.send_signal(:TERM)).to eq true
  end

  it "send_signal not ok" do
    expect(Eye::System).to receive(:send_signal).with(@process.pid, :TERM){ {:error => Exception.new('bla')} }
    expect(@process.send_signal(:TERM)).to eq false
  end

  it "pid_file_ctime" do
    File.open(@process[:pid_file_ex], 'w'){|f| f.write("asdf") }
    sleep 1
    expect(Time.now - @process.pid_file_ctime).to be > 1.second

    @process.clear_pid_file
    expect(Time.now - @process.pid_file_ctime).to be < 0.1.second
  end

  [C.p1, C.p2].each do |cfg|
    it "blocking execute should not block process actor mailbox #{cfg[:name]}" do
      @process = Eye::Process.new(cfg.merge(:start_command => "sleep 5", :start_timeout => 10.seconds))
      should_spend(1) do
        @process.schedule :start
        sleep 1

        # here mailbox should anwser without blocks
        expect(@process.name).to eq cfg[:name]
      end
    end
  end

  it "execute_sync helper" do
    filename = "asdfasdfsd.tmp"
    full_filename = C.working_dir + "/" + filename
    FileUtils.rm(full_filename) rescue nil
    expect(File.exist?(full_filename)).to eq false
    res = @process.execute_sync("touch #{filename}")
    expect(File.exist?(full_filename)).to eq true
    FileUtils.rm(full_filename) rescue nil
    expect(res[:exitstatus]).to eq 0
  end

  it "execute_async helper" do
    filename = "asdfasdfsd.tmp"
    full_filename = C.working_dir + "/" + filename
    FileUtils.rm(full_filename) rescue nil
    expect(File.exist?(full_filename)).to eq false
    res = @process.execute_async("touch #{filename}")
    sleep 0.2
    expect(File.exist?(full_filename)).to eq true
    FileUtils.rm(full_filename) rescue nil
    expect(res[:exitstatus]).to eq 0
  end

  context "#wait_for_condition" do
    subject{ Eye::Process.new(C.p1) }

    it "success" do
      should_spend(0) do
        expect(subject.wait_for_condition(1){ 15 }).to eq 15
      end
    end

    it "success with sleep" do
      should_spend(0.3) do
        expect(subject.wait_for_condition(1){ sleep 0.3; :a }).to eq :a
      end
    end

    # it "fail by timeout" do
    #   should_spend(1) do
    #     expect(subject.wait_for_condition(1){ sleep 4; true }).to eq false
    #   end
    # end

    it "fail with bad result" do
      should_spend(1) do
        expect(subject.wait_for_condition(1){ nil }).to eq false
      end
    end
  end


end
