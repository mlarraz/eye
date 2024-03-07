require File.dirname(__FILE__) + '/spec_helper'

class Checker1 < Eye::Checker
  def get_value
    true
  end

  def good?(value)
    value
  end
end

class Checker2 < Eye::Checker
  param :bla, [String, Symbol]
  param :bla2, [String, Symbol], true
  param :bla3, [String, Symbol], true, "hi"
  param :bla4, [String, Symbol], false, "hi2"
  param :bla5, [Integer, Float]
end

describe "Eye::Checker" do

  it "defaults" do
    @c = Checker1.new(1, {:times => 3})
    expect(@c.max_tries).to eq 3
    expect(@c.min_tries).to eq 3
  end

  it "defaults" do
    @c = Checker1.new(1, {:times => [3, 5]})
    expect(@c.max_tries).to eq 5
    expect(@c.min_tries).to eq 3
  end

  it "defaults" do
    @c = Checker1.new(1, {})
    expect(@c.max_tries).to eq 1
    expect(@c.min_tries).to eq 1
  end

  describe "one digit" do
    before :each do
      @c = Checker1.new(1, {:times => 3, :bla => 1})
    end

    it "times 3 from 3" do
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
    end

    it "times 3 from 3" do
      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
    end

    it "times 3 from 3" do
      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq false
    end

  end

  describe "two digits" do
    before :each do
      @c = Checker1.new(1, {:times => [2,5], :bla => 1})
    end

    it "2 from 5" do
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true
    end

    it "times 2 from 5" do
      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
    end


    it "times 2 from 5" do
      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true
      allow(@c).to receive(:get_value).and_return(false)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq false

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq false

      allow(@c).to receive(:get_value).and_return(true)
      expect(@c.check).to eq true
    end
  end

  describe "default validates" do
    it "validate by default" do
      Checker1.validate({:times => 3})
    end

    it "validate by default" do
      expect{ Checker1.validate({:times => "jopa"}) }.to raise_error(Eye::Dsl::Validation::Error)
    end
  end

  describe "initial_grace" do
    before :each do
      @c = Checker1.new(1, {:times => 2, :bla => 1, :initial_grace => 2.seconds})
    end

    it "should work" do
      allow(@c).to receive (:get_value) { false }
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true

      sleep 1
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true

      sleep 1
      expect(@c.check).to eq true
      expect(@c.check).to eq false
      expect(@c.check).to eq false
    end
  end

  describe "skip_initial_fails" do
    before :each do
      @c = Checker1.new(1, {:times => 2, :bla => 1, :skip_initial_fails => true})
    end

    it "should work" do
      allow(@c).to receive (:get_value) { false }
      expect(@c.check).to eq true
      expect(@c.check).to eq true

      sleep 0.1
      expect(@c.check).to eq true
      expect(@c.check).to eq true

      allow(@c).to receive (:get_value) { true }
      expect(@c.check).to eq true
      expect(@c.check).to eq true
      expect(@c.check).to eq true

      allow(@c).to receive (:get_value) { false }
      expect(@c.check).to eq true
      expect(@c.check).to eq false
      expect(@c.check).to eq false
    end
  end

  it "defaults every" do
    @c = Checker1.new(nil, {:times => 3})
    expect(@c.every).to eq 5
  end

  it "not defaults every" do
    @c = Checker1.new(nil, {:times => 3, :every => 10})
    expect(@c.every).to eq 10
  end

  describe "validates" do
    it "validate ok" do
      Checker2.validate({:bla2 => :a111})
      Checker2.validate({:bla2 => "111"})
      Checker2.validate({:bla2 => "111", :bla => :bla})
      Checker2.validate({:bla2 => "111", :bla5 => 10.minutes})
      Checker2.validate({:bla2 => "111", :bla5 => 15.4.seconds})

      c = Checker2.new(nil, :bla2 => :a111)
      expect(c.bla).to eq nil
      expect(c.bla2).to eq :a111
      expect(c.bla3).to eq 'hi'
      expect(c.bla4).to eq 'hi2'

      c = Checker2.new(nil, :bla2 => :a111, :bla3 => "ho", :bla => 'bla')
      expect(c.bla).to eq 'bla'
      expect(c.bla2).to eq :a111
      expect(c.bla3).to eq 'ho'
      expect(c.bla4).to eq 'hi2'
    end

    it "validate bad" do
      expect{ Checker2.validate({}) }.to raise_error
      expect{ Checker2.validate({:bla => :bla}) }.to raise_error
      expect{ Checker2.validate({:bla2 => 123}) }.to raise_error
      expect{ Checker2.validate({:bla2 => :hi, :bla3 => {}}) }.to raise_error
      expect{ Checker2.validate({:bla => :bla, :bla3 => 1, :bla4 => 2}) }.to raise_error
      expect{ Checker2.validate({:bla2 => :hi, :bla5 => []}) }.to raise_error
    end

  end

end
