require File.dirname(__FILE__) + '/../spec_helper'

class String
  def clean_info
    self.gsub(%r{\033.*?m}im, '').gsub(%r[\(.*?\)], '').gsub(%r|(\s+)$|, '')
  end
end

def app_check(app, name, gr_size)
  expect(app.name).to eq name
  expect(app.class).to eq Eye::Application
  expect(app.groups.size).to eq gr_size
  expect(app.groups.class).to eq Eye::Utils::AliveArray
end

def gr_check(gr, name, p_size, hidden = false)
  expect(gr.class).to eq Eye::Group
  expect(gr.processes.class).to eq Eye::Utils::AliveArray
  expect(gr.processes.size).to eq p_size
  expect(gr.name).to eq name
  expect(gr.hidden).to eq hidden
end

def p_check(p, name, pid_file)
  expect(p.name).to eq name
  expect(p.class).to eq Eye::Process
  expect(p[:pid_file]).to eq "#{pid_file}"
  expect(p[:pid_file_ex]).to eq "/tmp/#{pid_file}"
end

RSpec.describe "Eye::Controller" do
  subject{ Eye::Controller.new }

  it "should ok load config" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok

    apps = subject.applications

    app1 = apps.first
    app_check(app1, 'app1', 3)
    expect(app1.processes.map(&:name).sort).to eq ["g4", "g5", "p1", "p2", "q3"]

    app2 = apps.last
    app_check(app2, 'app2', 1)

    gr1 = app1.groups[0]
    gr_check(gr1, 'gr1', 2, false)
    gr2 = app1.groups[1]
    gr_check(gr2, 'gr2', 1, false)
    gr3 = app1.groups[2]
    gr_check(gr3, '__default__', 2, true)
    gr4 = app2.groups[0]
    gr_check(gr4, '__default__', 1, true)

    p1 = gr1.processes[0]
    p_check(p1, 'p1', "app1-gr1-p1.pid")
    p2 = gr1.processes[1]
    p_check(p2, 'p2', "app1-gr1-p2.pid")

    p3 = gr2.processes[0]
    p_check(p3, 'q3', "app1-gr2-q3.pid")

    p4 = gr3.processes[0]
    p_check(p4, 'g4', "app1-g4.pid")
    p5 = gr3.processes[1]
    p_check(p5, 'g5', "app1-g5.pid")

    p6 = gr4.processes[0]
    p_check(p6, 'z1', "app2-z1.pid")

    expect(subject.wrapped_object.class.to_s).to eq "Eye::Controller"
  end

  it "raise when load config" do
    result = subject.load(fixture("dsl/bad.eye"))
    expect(result.size).to eq(1)
    expect(result.values.first).to include(:error => true, :message => "blank pid_file for: bad")
  end

  it "should save cache file" do
    FileUtils.rm(Eye::Local.cache_path) rescue nil
    subject.load(fixture("dsl/load.eye"))
    expect(File.exist?(Eye::Local.cache_path)).to eq false
  end

  it "should delete all apps" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    subject.apply(%w{all}, :command => :delete)
    expect(subject.applications).to be_empty
  end

  it "[bug] delete was crashed when we have 1 process and same named app" do
    subject.load_content(<<-D)
      Eye.application("bla") do
        process("bla") do
          pid_file "#{C.p1_pid}"
        end
      end
    D
    subject.command('delete', 'bla')
    expect(subject.alive?).to eq true
  end

  describe "command" do
    it "should apply" do
      expect(subject.wrapped_object).to receive(:apply).with(%w{samples}, :command => :restart, :signal=>nil)
      subject.command('restart', 'samples')
    end

    it "should apply" do
      expect(subject.wrapped_object).to receive(:apply).with(%w{samples blah}, :command => :restart, :signal=>nil)
      subject.command(:restart, 'samples', 'blah')
    end

    it "should apply" do
      expect(subject.wrapped_object).to receive(:apply).with([], :command => :restart, :signal=>nil)
      subject.command(:restart)
    end

    it "load" do
      expect(subject.wrapped_object).to receive(:load).with('/tmp/file')
      subject.command('load', '/tmp/file')
    end

    it "info" do
      expect(subject.wrapped_object).to receive(:info_data)
      subject.command('info_data')
    end

    it "quit" do
      expect(subject.wrapped_object).to receive(:quit)
      subject.command('quit')
    end

  end

  it "find_nearest_process" do
    expect(subject.load(fixture("dsl/load_dupls5.eye"))).to be_ok

    p = subject.find_nearest_process('app1:p1')
    expect(p.full_name).to eq 'app1:p1'

    p = subject.find_nearest_process('p1')
    expect(p.full_name).to eq 'app1:a:p1'

    p = subject.find_nearest_process('asdfasdfsd')
    expect(p).to eq nil

    p = subject.find_nearest_process('p1', 'a')
    expect(p.full_name).to eq 'app1:a:p1'

    p = subject.find_nearest_process('p1', '__default__', 'app2')
    expect(p.full_name).to eq 'app2:p1'

    p = subject.find_nearest_process('p3', 'a')
    expect(p.full_name).to eq 'app1:p3'

    p = subject.find_nearest_process('p4', 'a', 'app1')
    expect(p.full_name).to eq 'app2:p4'
  end
end
