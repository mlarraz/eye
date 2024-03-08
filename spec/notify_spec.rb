require File.dirname(__FILE__) + '/spec_helper'

class Not1 < Eye::Notify
  param :port, Integer

  def execute
  end
end

describe "Eye::Notify" do
  before :each do
    @message = {:message=>"something", :name=>"blocking process",
        :full_name=>"main:default:blocking process", :pid=>123,
        :host=>'host1', :level=>:crit, :at => Time.now}

  end

  context "create notify class" do
    before :each do
      @config = {
        :mail=>{:host=>"mx.some.host.ru", :type => :mail, :port => 25, :domain => "some.host"},
        :contacts=>{
          "vasya"=>{:name=>"vasya", :type=>:mail, :contact=>"vasya@mail.ru", :opts=>{}},
          "petya"=>{:name=>"petya", :type=>:mail, :contact=>"petya@mail.ru", :opts=>{:port=>1111}},
          'idiots'=>[{:name=>"idiot1", :type=>:mail, :contact=>"idiot1@mail.ru", :opts=>{}}, {:name=>"idiot2", :type=>:mail, :contact=>"idiot2@mail.ru", :opts=>{:port=>1111}}],
          "idiot1"=>{:name=>"idiot1", :type=>:mail, :contact=>"idiot1@mail.ru", :opts=>{}},
          "idiot2"=>{:name=>"idiot2", :type=>:mail, :contact=>"idiot2@mail.ru", :opts=>{:port=>1111}},
          "idiot3"=>{:name=>"idiot3", :type=>:jabber, :contact=>"idiot3@mail.ru", :opts=>{:host => "jabber.some.host", :port=>1111, :user => "some_user"}}}}

      allow(Eye::Control).to receive(:current_config) { Eye::Config.new(@config, {}) }
    end

    it "should create right class" do
      h = {:host=>"mx.some.host.ru", :type=>:mail, :port=>25, :domain=>"some.host", :contact=>"vasya@mail.ru"}
      expect(Eye::Notify::Mail).to receive(:new).with(h, @message)
      Eye::Notify.notify('vasya', @message)
    end

    it "should create right class with additional options" do
      h = {:host=>"mx.some.host.ru", :type=>:mail, :port=>1111, :domain=>"some.host", :contact=>"petya@mail.ru"}
      expect(Eye::Notify::Mail).to receive(:new).with(h, @message)
      Eye::Notify.notify('petya', @message)
    end

    it "should create right class with group of contacts" do
      h1 = {:host=>"mx.some.host.ru", :type=>:mail, :port=>25, :domain=>"some.host", :contact=>"idiot1@mail.ru"}
      h2 = {:host=>"mx.some.host.ru", :type=>:mail, :port=>1111, :domain=>"some.host", :contact=>"idiot2@mail.ru"}
      expect(Eye::Notify::Mail).to receive(:new).with(h1, @message)
      expect(Eye::Notify::Mail).to receive(:new).with(h2, @message)
      Eye::Notify.notify('idiots', @message)
    end

    it "without contact should do nothing" do
      expect(Eye::Notify::Mail).not_to receive(:new)
      Eye::Notify.notify('noperson', @message)
    end

    it "should also notify to jabber" do
      h = {:host=>"jabber.some.host", :port=>1111, :user=>"some_user", :contact=>"idiot3@mail.ru"}
      expect(Eye::Notify::Jabber).to receive(:new).with(h, @message)
      Eye::Notify.notify('idiot3', @message)
    end
  end

  context "initialize" do
    before :each do
      @h = {:host=>"mx.some.host.ru", :type=>:mail, :port=>25, :domain=>"some.host", :contact=>"vasya@mail.ru"}
    end

    it "create and intall async task" do
      n = Not1.new(@h, @message)

      $wo = nil
      expect(n).to receive(:execute) do
        $wo = n.wrapped_object
      end

      n.async_notify
      sleep 0.5
      expect(n.alive?).to eq false

      expect($wo.contact).to eq 'vasya@mail.ru'
      expect($wo.port).to eq 25

      expect($wo.message_subject).to eq '[host1] [main:default:blocking process] something'
      expect($wo.message_body).to start_with('[host1] [main:default:blocking process] something at')
    end
  end

end
