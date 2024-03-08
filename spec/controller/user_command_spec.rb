require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Controller user_command" do
  subject { Eye::Controller.new }

  it "should execute string cmd" do
    cfg = <<-D
      Eye.application("app") do
        process("proc") do
          pid_file "#{C.p1_pid}"
          start_command "sleep 10"
          daemonize!
          start_grace 0.3

          command :abcd, "touch #{C.tmp_file}"
        end
      end
    D

    subject.load_content(cfg)
    sleep 0.5

    expect(File.exist?(C.tmp_file)).to eq false
    subject.command('user_command', 'abcd', 'proc')
    sleep 0.5
    expect(File.exist?(C.tmp_file)).to eq true
  end

  it "should send notify when command exitstatus != 0" do
    cfg = <<-D
      Eye.application("app") do
        process("proc") do
          pid_file "#{C.p1_pid}"
          start_command "sleep 10"
          daemonize!
          start_grace 0.3

          command :abcd, "ruby -e 'exit 1'"
        end
      end
    D

    subject.load_content(cfg)
    @process = subject.process_by_name("proc")
    expect(@process).to receive(:notify).with(:debug, anything)
    sleep 0.5
    subject.command('user_command', 'abcd', 'proc')
    sleep 2.0
  end

  it "should execute signals cmd" do

    cfg = <<-D
      Eye.application("app") do
        process("proc") do
          pid_file "#{C.p1_pid}"
          start_command "sleep 10"
          daemonize!
          start_grace 0.3

          command :abcd, [:quit, 0.2, :term, 0.1, :kill]
        end
      end
    D

    subject.load_content(cfg)
    sleep 0.5

    @process = subject.process_by_name("proc")
    expect(Eye::System.pid_alive?(@process.pid)).to eq true

    subject.command('user_command', 'abcd', 'app')
    sleep 2.5

    expect(Eye::System.pid_alive?(@process.pid)).to eq false
  end

  it "check identity before execute user_command" do
    cfg = <<-D
      Eye.application("app") do
        process("proc") do
          pid_file "#{C.p1_pid}"
          start_command "sleep 10"
          daemonize!
          start_grace 0.3

          command :abcd, "touch #{C.tmp_file}"
        end
      end
    D

    subject.load_content(cfg)
    @process = subject.process_by_name("proc")
    expect(File.exist?(C.tmp_file)).to eq false
    sleep 1
    change_ctime(C.p1_pid, 5.days.ago)
    subject.command('user_command', 'abcd', 'proc')
    sleep 1
    expect(File.exist?(C.tmp_file)).to eq false
  end

end
