require_relative '../../../lib/jir/jql'

describe Jir::Jql do
  it 'renders escaped arguments' do
    actual = described_class.new("abc=%1 and def=%2").render(["foo", "bar"])
    expected = 'abc="foo" and def="bar"'
    expect(actual).to eq(expected)
  end

  it 'allows escaped % signs' do
    actual = described_class.new("abc=%%%1 and def=%%1").render(["foo"])
    expected = 'abc=%"foo" and def=%1'
    expect(actual).to eq(expected)
  end

  it 'raises an error if passed the wrong number of args' do
    expect do
      described_class.new("abc=%1 and def=%2").render(["foo"])
    end.to raise_error(described_class::WrongNumberOfArgs)
    expect do
      described_class.new("abc=%1 and def=%2").render(["foo", "bar", "waz"])
    end.to raise_error(described_class::WrongNumberOfArgs)
  end
end
