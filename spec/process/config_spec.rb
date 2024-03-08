require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Process::Config" do

  it "should use throught [], c" do
    @p = Eye::Process.new({:pid_file => '1.pid', :start_command => "a", :working_dir => "/tmp"})
    expect(@p[:pid_file]).to eq "1.pid"
    expect(@p[:pid_file_ex]).to eq "/tmp/1.pid"
    expect(@p[:checks]).to eq({})
  end

  it "c interface" do
    @p = Eye::Process.new({:pid_file => '/tmp/1.pid', :start_command => "a"})
    expect(@p.c(:pid_file_ex)).to eq "/tmp/1.pid"
  end

  it "should expand stdout" do
    @p = Eye::Process.new({:working_dir => "/tmp", :stdout => '1.log', :start_command => "a", :pid_file => '/tmp/1.pid'})
    expect(@p[:stdout]).to eq "/tmp/1.log"
  end

  it "check and triggers should {} if empty" do
    @p = Eye::Process.new({:working_dir => "/tmp", :stdout => '1.log', :start_command => "a", :pid_file => '/tmp/1.pid', :triggers => {}})
    expect(@p[:checks]).to eq({})
    expect(@p[:triggers]).to eq({:flapping => {:type=>:flapping, :times=>10, :within=>10}})
  end

  it "if trigger setted, no rewrite" do
    @p = Eye::Process.new({:working_dir => "/tmp", :stdout => '1.log', :start_command => "a", :pid_file => '/tmp/1.pid', :triggers => {:flapping => {:type=>:flapping, :times=>100, :within=>100}}})
    expect(@p[:triggers]).to eq({:flapping => {:type=>:flapping, :times=>100, :within=>100}})
  end

  it "clear_pid default" do
    @p = Eye::Process.new({:pid_file => '/tmp/1.pid'})
    expect(@p[:clear_pid]).to eq true
  end

  it "should set default stop_signals" do
    @p = Eye::Process.new({:working_dir => "/tmp", :start_command => "a", :pid_file => '/tmp/1.pid'})
    expect(@p[:stop_signals]).to eq [:TERM, 0.5, :KILL]

    @p = Eye::Process.new({:working_dir => "/tmp", :start_command => "a", :pid_file => '/tmp/1.pid', :stop_signals => [:KILL]})
    expect(@p[:stop_signals]).to eq [:KILL]

    @p = Eye::Process.new({:working_dir => "/tmp", :start_command => "a", :pid_file => '/tmp/1.pid', :stop_command => "kill -9 {PID}"})
    expect(@p[:stop_signals]).to eq nil
  end

  describe "control_pid?" do
    it "if daemonize than true" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid', :daemonize => true})
      expect(@p.control_pid?).to eq true
    end

    it "if not daemonize than false" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid'})
      expect(@p.control_pid?).to eq false
    end
  end

  it "skip_group_action" do
    @p = Eye::Process.new({:skip_group_actions => {:stop => true}, :pid_file => '/tmp/1.pid'})
    expect(@p.skip_group_action?(:stop)).to eq true
    expect(@p.skip_group_action?(:restart)).to eq nil
  end

  it "skip_group_action? performs array or allowed states" do
    @p = Eye::Process.new({:skip_group_actions => {:stop => [:up, :down]}, :pid_file => '/tmp/1.pid'})
    @p.state = :up
    expect(@p.skip_group_action?(:stop)).to eq true
    expect(@p.skip_group_action?(:restart)).to eq nil

    @p.state = :unmonitored
    expect(@p.skip_group_action?(:stop)).to eq false
    expect(@p.skip_group_action?(:restart)).to eq nil
  end

  describe ":children_update_period" do
    it "should set default" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid'})
      expect(@p[:children_update_period]).to eq 30.seconds
    end

    it "should set from global options" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid', :children_update_period => 11.seconds})
      expect(@p[:children_update_period]).to eq 11.seconds
    end

    it "should set from monitor_children sub options" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid', :monitor_children => {:children_update_period => 12.seconds}})
      expect(@p[:children_update_period]).to eq 12.seconds
    end

    it "should set from monitor_children sub options" do
      @p = Eye::Process.new({:pid_file => '/tmp/1.pid', :children_update_period => 11.seconds, :monitor_children => {:children_update_period => 12.seconds}})
      expect(@p[:children_update_period]).to eq 12.seconds
    end

  end

end
