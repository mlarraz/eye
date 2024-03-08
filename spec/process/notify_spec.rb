require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Process::Notify" do
  before :each do
    allow(Eye::Local).to receive(:host) { 'host1' }
    @process = process(C.p1.merge(:notify => {'vasya' => :info,
      'petya' => :warn, 'somebody' => :warn}))
  end

  it "should send to notifies warn message" do
    m = {:message=>"something", :name=>"blocking process", :full_name=>"main:default:blocking process", :pid=>nil, :host=>"host1", :level=>:info}
    expect(Eye::Notify).to receive(:notify).with('vasya', hash_including(m))
    @process.notify(:info, 'something')
  end

  it "should send to notifies crit message" do
    m = {:message=>"something", :name=>"blocking process",
      :full_name=>"main:default:blocking process", :pid=>nil,
      :host=>'host1', :level=>:warn}

    expect(Eye::Notify).to receive(:notify).with('vasya', hash_including(m))
    expect(Eye::Notify).to receive(:notify).with('petya', hash_including(m))
    expect(Eye::Notify).to receive(:notify).with('somebody', hash_including(m))
    @process.notify(:warn, 'something')
  end

end
