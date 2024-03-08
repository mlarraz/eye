require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Notify::Jabber" do
  before :each do
    @message = {:message=>"something", :name=>"blocking process",
        :full_name=>"main:default:blocking process", :pid=>123,
        :host=>'host1', :level=>:crit, :at => Time.now}
    @h = {:host=>"mx.some.host.ru", :type=>:mail, :port=>25, :contact=>"vasya@mail.ru", :password => "123"}
  end

  it "should send jabber" do
    require 'xmpp4r'

    @m = Eye::Notify::Jabber.new(@h, @message)

    ob = double
    expect(Jabber::Client).to receive(:new).with(anything){ ob }
    expect(ob).to receive(:connect).with('mx.some.host.ru', 25)
    expect(ob).to receive(:auth).with('123')
    expect(ob).to receive(:send).with(kind_of(Jabber::Message))
    expect(ob).to receive(:close)

    @m.execute
  end
end
