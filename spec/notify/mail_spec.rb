require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Notify::Mail" do
  before :each do
    @message = {:message=>"something", :name=>"blocking process",
        :full_name=>"main:default:blocking process", :pid=>123,
        :host=>'host1', :level=>:crit, :at => Time.now}
    @h = {:host=>"mx.some.host.ru", :type=>:mail, :port=>25, :domain=>"some.host", :contact=>"vasya@mail.ru"}
  end

  it "should send mail" do
    @m = Eye::Notify::Mail.new(@h, @message)

    smtp = Net::SMTP.new 'mx.some.host.ru', 25
    expect(Net::SMTP).to receive(:new).with('mx.some.host.ru', 25) { smtp }

    ob = double
    expect(smtp).to receive(:start).with('some.host', nil, nil, nil) { ob }

    @m.execute

    expect(@m.message_subject).to eq "[host1] [main:default:blocking process] something"
    expect(@m.contact).to eq "vasya@mail.ru"

    m = @m.message.split("\n")
    expect(m).to include("To: <vasya@mail.ru>")
    expect(m).to include("Subject: [host1] [main:default:blocking process] something")
  end
end
