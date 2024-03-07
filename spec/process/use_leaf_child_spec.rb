require File.dirname(__FILE__) + '/../spec_helper'

describe "Process with use_leaf_child" do

  before { @process = process(C.p6) }

  # monitor leaf child in process tree
  # sh -c
  #   sleep 10

  # pid should of `sleep 10`

  it "start" do
    @process.start
    ps = `ps ax | grep #{@process.pid} | grep -v grep`
    expect(ps).to include('sleep 10')
    expect(ps).not_to include('sh -c')
    expect(@process.pid).to be
    expect(@process.parent_pid).to be
    expect(@process.parent_pid).not_to eq @process.pid
    expect(@process.state_name).to eq :up

    expect(Eye::System.pid_alive?(@process.pid)).to eq true
    expect(Eye::System.pid_alive?(@process.parent_pid)).to eq true
  end

  it "stop" do
    @process.start
    expect(Eye::System.pid_alive?(@process.pid)).to eq true
    expect(Eye::System.pid_alive?(@process.parent_pid)).to eq true
    expect(`ps ax | grep #{C.p6_word} | grep -v grep`).not_to be_blank

    @process.stop
    expect(`ps ax | grep #{C.p6_word} | grep -v grep`).to be_blank

    # parent_pid also should die by itself
    expect(Eye::System.pid_alive?(@process.pid)).to eq nil
    expect(Eye::System.pid_alive?(@process.parent_pid)).to eq false
  end
end
