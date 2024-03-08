require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Controller data spec" do
  subject{ Eye::Controller.new }
  before { subject.load(fixture("dsl/load.eye")) }

  it "info_data" do
    res = subject.command(:info_data)
    st = res[:subtree]
    expect(st.size).to eq 2
    p = st[1][:subtree][0][:subtree][0]
    expect(p).to include(:name=>"z1", :state=>"unmonitored",
      :type=>:process, :resources=>{:memory=>nil, :cpu=>nil, :start_time=>nil, :pid=>nil})
  end

  it "info_data + filter" do
    res = subject.info_data('app2')
    st = res[:subtree]
    expect(st.size).to eq 1
    p = st[0][:subtree][0][:subtree][0]
    expect(p).to include(:name=>"z1", :state=>"unmonitored",
      :type=>:process, :resources=>{:memory=>nil, :cpu=>nil, :start_time=>nil, :pid=>nil})
  end

  it "short_data" do
    sleep 0.2
    res = subject.command(:short_data)
    expect(res).to eq({
      :subtree=>[
        {:name=>"app1", :type=>:application, :subtree=>[{:name=>"gr1", :type=>:group, :states=>{"unmonitored"=>2}},
        {:name=>"gr2", :type=>:group, :states=>{"unmonitored"=>1}}, {:name=>"default", :type=>:group, :states=>{"unmonitored"=>2}}]},
        {:name=>"app2", :type=>:application, :subtree=>[{:name=>"default", :type=>:group, :states=>{"unmonitored"=>1}}]}
      ]
    })
  end

  it "debug_data" do
    res = subject.command(:debug_data)
    expect(res[:resources]).to be_a(Hash)
    expect(res[:config_yaml]).to eq nil

    res = subject.debug_data(:config => true)
    expect(res[:resources]).to be_a(Hash)
    expect(res[:config_yaml]).to be_a(String)
  end

  it "history_data" do
    h = subject.command(:history_data, 'app1')
    expect(h.size).to eq 5
    expect(h.keys.sort).to eq ["app1:g4", "app1:g5", "app1:gr1:p1", "app1:gr1:p2", "app1:gr2:q3"]
  end

end
