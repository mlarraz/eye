require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Custom rspec matchers" do
  it "contain_only" do
    expect([1,2,9]).to contain_only(1, 9, 2)
    expect([1,2,9]).to contain_only(1, 2, 9)
    expect([1]).to contain_only(1)
    expect([1,2,9]).not_to contain_only(1, 2)
    expect([1,2,9]).not_to contain_only(1, 9)
    expect([1,2,9]).not_to contain_only(1, 2, 3)
    expect([1]).not_to contain_only(2)
    expect([1]).not_to contain_only(1, 2)
  end

  it "seq" do
    expect([1,2,:-,4]).to seq(1, 2)
    expect([1,2,:-,4]).to seq(2, :-)
    expect([1,2,:-,4]).to seq(1, 2, :-, 4)
    expect([1,2,:-,4]).to seq(4)
    expect([1,2,:-,4]).to seq(:-, 4)


    expect([1,2,:-,4]).not_to seq(4, :-)
    expect([1,2,:-,4]).not_to seq(5)
    expect([1,2,:-,4]).not_to seq(2, 1)
    expect([1,2,:-,4]).not_to seq(1, 2, :-, 5)
  end
end
