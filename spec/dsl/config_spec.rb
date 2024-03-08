require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Dsl::Config" do

  it "logger" do
    conf = <<-E
      Eye.config do
        logger "/tmp/1.loG"
      end
    E
    expect(Eye::Dsl.parse(conf).to_h).to eq({:applications => {}, :settings => {:logger => ["/tmp/1.loG"]}, :defaults => {}})
  end

  it "logger with params" do
    conf = <<-E
      Eye.config do
        logger "/tmp/1.loG", 'dayly', 1_000_000
      end
    E
    expect(Eye::Dsl.parse(conf).to_h).to eq({:applications => {}, :settings => {:logger => ["/tmp/1.loG", 'dayly', 1_000_000]}, :defaults => {}})
  end

  it "should merge sections" do
    conf = <<-E
      Eye.config do
        logger "/tmp/1.log"
        logger_level 2
      end

      Eye.config do
        logger "/tmp/2.log"
      end

    E
    expect(Eye::Dsl.parse(conf).to_h).to eq({
      :applications => {},
      :settings => {:logger => ["/tmp/2.log"], :logger_level => 2},
      :defaults => {}
    })
  end

end
