require File.dirname(__FILE__) + '/../../spec_helper'

RSpec.describe "Process Http check" do
  before :each do
    @c = C.p1.merge(
      :checks => C.check_http
    )
    FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody OK")
  end

  after :each do
    FakeWeb.clean_registry
  end

  it "all ok" do
    start_ok_process(@c)

    expect(@process).not_to receive(:schedule).with({ :command => :restart })

    # should not happens anything
    sleep 6
  end

  it "bad body" do
    start_ok_process(@c)
    sleep 2

    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })
    FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody BAD")
    sleep 2
  end

  it "bad status" do
    start_ok_process(@c)
    sleep 2

    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })
    FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody OK", :status => [500, 'err'])
    sleep 2
  end

  it "not responded url" do
    start_ok_process(@c)
    sleep 2

    expect(@process.wrapped_object).to receive(:schedule).with({ :command => :restart })
    FakeWeb.clean_registry
    FakeWeb.allow_net_connect = false
    sleep 2
  end

end
