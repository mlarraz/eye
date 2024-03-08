RSpec::Matchers.define :be_ok do |count = 1|
  match do |hash|
    expect(hash.size).to eq count
    expect(hash).to have_error_count 0
  end
end

RSpec::Matchers.define :have_error_count do |expected_count|
  match do |hash|
    hash.values.count{ |res| res[:error] } == expected_count
  end
end
