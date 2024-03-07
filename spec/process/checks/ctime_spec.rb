require File.dirname(__FILE__) + '/../../spec_helper'

describe "Check CTime" do
  before :each do
    @c = C.p1.merge(
      :checks => C.check_ctime(:times => 3)
    )
  end

  it "should start periodical watcher" do
    start_ok_process(@c)

    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_ctime]
    sbj = @process.watchers[:check_ctime][:subject]
    expect(sbj.file).to eq "#{C.sample_dir}/#{C.log_name}"

    @process.stop

    # after process stop should remove watcher
    expect(@process.watchers.keys).to eq []
  end

  it "if ctime changes should_not restart" do
    start_ok_process(@c)
    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_ctime]

    expect(@process).not_to receive(:schedule).with(:restart)

    sleep 6
  end

  it "if ctime not changed should restart" do
    start_ok_process(@c)

    expect(@process).to receive(:schedule).with(:command => :restart)

    sleep 3

    FileUtils.rm(C.p1[:stdout])

    sleep 5
  end

end
