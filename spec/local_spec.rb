require File.dirname(__FILE__) + '/spec_helper'

def join_path(arr)
  File.join(File.dirname(__FILE__), arr)
end

RSpec.describe "Eye::Local" do
  it "should find_eyefile" do
    expect(Eye::Local.find_eyefile(join_path %w[ fixtures ])).to eq nil
    expect(Eye::Local.find_eyefile(join_path %w[])).to eq nil

    result = join_path %w[ fixtures dsl Eyefile ]
    expect(Eye::Local.find_eyefile(join_path %w[ fixtures dsl ])).to eq result
    expect(Eye::Local.find_eyefile(join_path %w[ fixtures dsl configs ])).to eq result
    expect(Eye::Local.find_eyefile(join_path %w[ fixtures dsl subfolder3 sub ])).to eq result
  end
end
