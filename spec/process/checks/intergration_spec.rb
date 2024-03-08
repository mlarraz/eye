require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Process Integration checks" do
  before :each do
    @c = C.p1.merge(
      :checks => join(C.check_cpu, C.check_mem, C.check_ctime, C.check_http)
    )

    FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody OK")
  end

  it "should start periodical watcher" do
    start_ok_process(@c)

    expect(@process.watchers.keys).to eq [:check_alive, :check_identity, :check_cpu, :check_memory, :check_ctime, :check_http]

    @process.stop

    # after process stop should remove watcher
    expect(@process.watchers.keys).to eq []
  end

  it "intergration" do
    start_ok_process(@c)

    expect(@process.wrapped_object).not_to receive(:schedule).with(:restart)

    # should not happens anything
    sleep 10
  end

  it "timeouted http, should not lock actor-mailbox" do
    cfg = C.p5.merge(
      :checks => join(C.check_http(
          :url => "http://127.0.0.1:#{C.p5_port}/timeout", :timeout => 6.seconds, :every => 5.seconds,
          :times => 3),
         C.check_cpu(:every => 1.second)
       )
    )

    start_ok_process(cfg)

    should_spend(10, 0.5) do
      10.times do
        expect(@process.name).to be_a(String) # actor should be free here
        sleep 1
      end
    end

    w_http = @process.watchers[:check_http][:subject]
    w_cpu = @process.watchers[:check_cpu][:subject]
    expect(w_http.check_count).to be <= 2
    expect(w_cpu.check_count).to be >= 9

    expect(w_http.inspect.size).to be > 100
  end

  it "timeouted socket, should not lock actor-mailbox" do
    cfg = C.p4.merge(
      :checks => join(C.check_sock(:timeout => 6.seconds, :every => 5.seconds,
          :times => 3, :send_data => "timeout"),
         C.check_cpu(:every => 1.second)
       )
    )

    start_ok_process(cfg)

    should_spend(10, 1) do
      10.times do
        expect(@process.name).to be_a(String) # actor should be free here
        sleep 1
      end
    end

    w_socket = @process.watchers[:check_socket][:subject]
    w_cpu = @process.watchers[:check_cpu][:subject]
    expect(w_socket.check_count).to be <= 2
    expect(w_cpu.check_count).to be >= 9
  end

end
