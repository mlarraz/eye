require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Check FSize" do
  before :each do
    @c = C.p1.merge(
      :checks => C.check_fsize(:times => 3)
    )
  end

  it "should start periodical watcher" do
    start_ok_process(@c)

    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_fsize]

    @process.stop

    # after process stop should remove watcher
    expect(@process.watchers.keys).to eq []
  end

end
