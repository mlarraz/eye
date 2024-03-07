require File.dirname(__FILE__) + '/spec_helper'

class A22 # duck
  def logger_tag
    "some"
  end
  def full_name
  end
end

describe "Eye::Logger" do
  it "should use smart logger with auto prefix" do
    expect(Eye::Process.logger.prefix).to eq "Eye::Process"
    expect(Eye.logger.prefix).to eq "Eye"
    expect(Eye::Checker.logger.prefix).to eq "Eye::Checker"
    expect(Eye::Checker.create(123, {:type => :cpu, :every => 5.seconds, :times => 1}, A22.new).logger.prefix).to eq "some"
    expect(Eye::Server.new(C.socket_path).logger.prefix).to eq "<Eye::Server>"
    expect(Eye::Controller.new.logger.prefix).to eq "Eye"
    expect(Eye::Process.new(C.p1).logger.prefix).to eq "main:default:blocking process"
  end
end
