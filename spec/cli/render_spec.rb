require File.dirname(__FILE__) + '/../spec_helper'

class String
  def clean_info
    self.gsub(%r{\033.*?m}im, '').gsub(%r[\(.*?\)], '').gsub(%r|(\s+)$|, '')
  end
end

describe "Eye::Cli" do
  let(:controller) { Eye::Controller.new }
  let(:cli) { Eye::Cli.new }

  def info_string(*args)
    cli.send(:render_info, controller.info_data(*args)).clean_info
  end

  def short_string(*args)
    cli.send(:render_info, controller.short_data(*args)).clean_info
  end

  def debug_string(*args)
    cli.send(:render_debug_info, controller.debug_data(*args)).clean_info
  end

  def history_string(*args)
    cli.send(:render_history, controller.history_data(*args)).clean_info
  end

  def status(*args)
    cli.send(:render_status, controller.info_data(*args))
  end

  it "render_info" do
    app1 = <<S
app1
  gr1
    p1 ............................ unmonitored
    p2 ............................ unmonitored
  gr2
    q3 ............................ unmonitored
  g4 .............................. unmonitored
  g5 .............................. unmonitored
S
    app2 = <<S
app2
  z1 .............................. unmonitored
S

    controller.load(fixture("dsl/load.eye"))
    sleep 0.5
    expect(info_string.strip).to eq (app1 + app2).strip
    expect(info_string('app1')).to eq app1.chomp
    expect(info_string('app2').strip).to eq app2.strip
    expect(info_string('app3', :some_arg => :ignored)).to eq ''

    # wrong arg should not crash
    expect(info_string(['1'])).to eq ''
  end

  it "render_info with reason" do
    controller.load(fixture("dsl/load.eye"))
    controller.command(:start)
    controller.command(:stop)
    sleep 0.5
    expect(info_string).to be
  end

  it "info_string_debug should be" do
    controller.load(fixture("dsl/load.eye"))
    expect(debug_string.split("\n").size).to be > 5

    controller.load(fixture("dsl/load.eye"))
    expect(debug_string(:config => true, :processes => true).split("\n").size).to be > 5
  end

  it "info_string_short should be" do
    controller.load(fixture("dsl/load.eye"))
    expect(short_string).to eq "app1\n  gr1 ............................. unmonitored:2\n  gr2 ............................. unmonitored:1\n  default ......................... unmonitored:2\napp2\n  default ......................... unmonitored:1"
  end

  it "history_string" do
    controller.load(fixture("dsl/load.eye"))
    sleep 0.3
    str = history_string('*')
    expect(str).to be_a(String)
    expect(str.size).to be >= 80
  end

  it "render_status" do
    controller.load(fixture("dsl/load.eye"))
    expect(status('p1')).to eq [3, '']
    expect(status('gr2')).to eq [1, "unknown status for :group=gr2"]
    expect(status('gr')).to eq [1, "match 2 objects ([\"gr1\", \"gr2\"]), but expected only 1 process"]

    p = controller.process_by_name('p1')

    p.state = :restarting
    expect(status('p1')).to eq [4, "process p1 state :restarting"]

    p.state = :up
    expect(status('p1')).to eq [0, '']
  end

end
