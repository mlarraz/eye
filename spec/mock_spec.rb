require File.dirname(__FILE__) + '/spec_helper'

class Aaa
  include Celluloid

  def int
    1
  end

  def ext
    int
  end

end

RSpec.describe "Actor mocking" do
  before :each do
    @a = Aaa.new
  end

  it "int" do
    expect(@a).to receive(:int) { 2 }
    expect(@a.int).to eq 2
  end

  it "ext" do
    expect(@a).to receive(:int) { 2 }
    expect(@a.ext).to eq 2
  end
end
