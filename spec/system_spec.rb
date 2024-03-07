require File.dirname(__FILE__) + '/spec_helper'

describe "Eye::System" do

  it "pid_alive?" do
    expect(Eye::System.pid_alive?($$)).to eq true
    expect(Eye::System.pid_alive?(123456)).to eq false
    expect(Eye::System.pid_alive?(-122)).to eq false
    expect(Eye::System.pid_alive?(nil)).to eq nil
  end

  it "check_pid_alive" do
    expect(Eye::System.check_pid_alive($$)).to eq({:result => 1})
    expect(Eye::System.check_pid_alive(123456)[:error].class).to eq Errno::ESRCH
    expect(Eye::System.check_pid_alive(-122)[:error]).to be
    expect(Eye::System.check_pid_alive(nil)).to eq({:result => false})
  end

  it "prepare env" do
    expect(Eye::System.send(:prepare_env, {})).to eq({})
    expect(Eye::System.send(:prepare_env, {:environment => {'A' => 'B'}})).to eq({'A' => 'B'})
    expect(Eye::System.send(:prepare_env, {:environment => {'A' => 'B'}, :working_dir => "/tmp"})).to eq({'A' => 'B'})

    r = Eye::System.send(:prepare_env, {:environment => {'A' => [], 'B' => {}, 'C' => nil, 'D' => 1, 'E' => '2'}})
    expect(r).to eq(
      'A' => '[]',
      'B' => '{}',
      'C' => nil,
      'D' => '1',
      'E' => '2'
    )
  end

  it "set spawn_options" do
    allow(Eye::Local).to receive(:root?) { true }
    expect(Eye::System.send(:spawn_options, {})).to eq({:pgroup => true, :chdir => "/"})
    expect(Eye::System.send(:spawn_options, {:working_dir => "/tmp"})).to include(:chdir => "/tmp")
    expect(Eye::System.send(:spawn_options, {:stdout => "/tmp/1", :stderr => "/tmp/2"})).to include(:out => ["/tmp/1", 'a'], :err => ["/tmp/2", 'a'])
    expect(Eye::System.send(:spawn_options, {:clear_env => true})).to include({:unsetenv_others => true})

    # root user exists
    expect(Etc).to receive(:getpwnam).with('root') { OpenStruct.new(:uid => 0) }
    # user asdf does not exist
    allow(Etc).to receive(:getpwnam).with('asdf') { raise "can't find user for asdf" }
    # However, group asdf does exist
    expect(Etc).to receive(:getgrnam).with('asdf') { OpenStruct.new(:gid => 1234) }
    expect(Eye::System.send(:spawn_options, {:uid => "root", :gid => "asdf"})).to include({:uid => 0, :gid => 1234})
  end

  describe "daemonize" do
    it "daemonize default" do
      @pid = Eye::System.daemonize("ruby sample.rb", {:environment => {"ENV1" => "SECRET1", 'BLA' => {}},
        :working_dir => C.p1[:working_dir], :stdout => @log})[:pid]

      expect(@pid).to be > 0

      # process should be alive
      expect(Eye::System.pid_alive?(@pid)).to eq true

      sleep 4

      # should capture log
      data = File.read(@log)
      expect(data).to include("SECRET1")
      expect(data).to include("- tick")
    end

    it "daemonize empty" do
      @pid = Eye::System.daemonize("ruby sample.rb", {:working_dir => C.p1[:working_dir]})[:pid]

      # process should be alive
      expect(Eye::System.pid_alive?(@pid)).to eq true
    end

    it "daemonize empty" do
      @pid = Eye::System.daemonize("echo 'some'", {:stdout => @log})[:pid]

      sleep 0.3

      data = File.read(@log)
      expect(data).to eq "some\n"
    end

    it "should provide all to spawn correctly" do
      args = [{"A"=>"1", "B"=>nil, "C"=>"3"}, "echo", "1",
        {:pgroup=>true, :chdir=>"/", :out=>["/tmp/1", "a"], :err=>["/tmp/2", "a"]}]
      expect(Process).to receive(:spawn).with(*args){ 1234555 }
      expect(Process).to receive(:detach).with( 1234555 )
      Eye::System::daemonize("echo 1", :environment => {'A' => 1, 'B' => nil, 'C' => 3},
        :stdout => "/tmp/1", :stderr => "/tmp/2")
    end
  end

  describe "execute" do
    it "sleep and exit" do
      should_spend(1, 0.3) do
        Eye::System.execute("sleep 1")
      end
    end
  end

  describe "send signal" do
    it "send_signal to spec" do
      expect(Eye::System.send_signal($$, 0)[:result]).to eq :ok
    end

    it "send_signal to unexisted process" do
      res = Eye::System.send_signal(-12234)
      expect(res[:status]).to eq nil
      expect(res[:error].message).to include("No such process")
    end

    it "send_signal to daemon" do
      @pid = Eye::System.daemonize("ruby sample.rb", {:working_dir => C.p1[:working_dir]})[:pid]

      # process should be alive
      expect(Eye::System.pid_alive?(@pid)).to eq true

      expect(Eye::System.send_signal(@pid, :term)[:result]).to eq :ok
      sleep 0.2

      expect(Eye::System.pid_alive?(@pid)).to eq false
    end

    it "catch signal in fork" do
      @pid = Eye::System.daemonize("ruby sample.rb", {:working_dir => C.p1[:working_dir],
        :stdout => @log})[:pid]

      sleep 4

      expect(Eye::System.send_signal(@pid, :usr1)[:result]).to eq :ok

      sleep 0.5

      data = File.read(@log)
      expect(data).to include("USR1 sig")
    end

    it "signals transformation" do
      expect(Process).to receive(:kill).with('USR1', 123)
      Eye::System.send_signal(123, :usr1)

      expect(Process).to receive(:kill).with('KILL', 123)
      Eye::System.send_signal(123, :KILL)

      expect(Process).to receive(:kill).with('USR1', 123)
      Eye::System.send_signal(123, 'usr1')

      expect(Process).to receive(:kill).with('KILL', 123)
      Eye::System.send_signal(123, 'KILL')

      expect(Process).to receive(:kill).with(9, 123)
      Eye::System.send_signal(123, 9)

      expect(Process).to receive(:kill).with(9, 123)
      Eye::System.send_signal(123, '9')

      expect(Process).to receive(:kill).with(9, 123)
      Eye::System.send_signal(123, '-9')

      expect(Process).to receive(:kill).with(9, 123)
      Eye::System.send_signal(123, -9)

      expect(Process).to receive(:kill).with(0, 123)
      Eye::System.send_signal(123, '0')
    end
  end

  it "normalized_file" do
    expect(Eye::System.normalized_file("/tmp/1.rb")).to eq "/tmp/1.rb"
    expect(Eye::System.normalized_file("/tmp/1.rb", '/usr')).to eq "/tmp/1.rb"

    expect(Eye::System.normalized_file("tmp/1.rb")).to eq Dir.getwd + "/tmp/1.rb"
    expect(Eye::System.normalized_file("tmp/1.rb", '/usr')).to eq "/usr/tmp/1.rb"

    expect(Eye::System.normalized_file("./tmp/1.rb")).to eq Dir.getwd + "/tmp/1.rb"
    expect(Eye::System.normalized_file("./tmp/1.rb", '/usr/')).to eq "/usr/tmp/1.rb"

    expect(Eye::System.normalized_file("../tmp/1.rb", '/usr/')).to eq "/tmp/1.rb"
  end

end
