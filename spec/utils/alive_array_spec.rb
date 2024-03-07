require File.dirname(__FILE__) + '/../spec_helper'

class AliveArrayActor
  include Celluloid

  attr_reader :name

  def initialize(name)
    @name = name
  end
end

describe "Eye::Utils::AliveArray" do

  it "act like array" do
    a = Eye::Utils::AliveArray.new([1,2,3])
    expect(a.size).to eq 3
    expect(a.empty?).to eq false
    a << 4
    expect(a.pure).to eq [1,2,3,4]
  end

  it "alive actions" do
    a = AliveArrayActor.new('a')
    b = AliveArrayActor.new('b'); b.terminate
    c = AliveArrayActor.new('c')

    l = Eye::Utils::AliveArray.new([a,b,c])
    expect(l.size).to eq 3
    expect(l.map(&:name).sort).to eq %w{a c}

    expect(l.detect{|c| c.name == 'a'}.name).to eq 'a'
    expect(l.detect{|c| c.name == 'b'}).to eq nil

    expect(l.any?{|c| c.name == 'a'}).to eq true
    expect(l.any?{|c| c.name == 'b'}).to eq false

    expect(l.include?(a)).to eq true
    expect(l.include?(b)).to eq false

    expect(l.sort_by(&:name).class).to eq Eye::Utils::AliveArray
    expect(l.sort_by(&:name).pure).to eq [a, c]

    expect(l.to_a.map(&:name).sort).to eq %w{a c}

    a.terminate
    c.terminate
  end
end
