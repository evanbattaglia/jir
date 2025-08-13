require_relative '../../spec_helper'
require_relative '../../../lib/jir/search_builder'

RSpec.describe Jir::SearchBuilder do
  before(:all) do
    @fixture = YAML.load_file(File.expand_path("../../fixtures/example.yml", __dir__))
  end

  before do
    allow(Jir::Config).to receive(:searches).and_return(@fixture['searches'])
    allow(Jir::Config).to receive(:outputs).and_return(@fixture['outputs'])
  end

  describe '.build' do
    {
      'finds a named search (JQL string)' => [
        ["simple_string", nil], {jql: "(abc=123)"}
      ],
      'handles named search (hash)' => [
        ["simple_hash", nil], {jql: "(def=456)", max_results: 789}
      ],
      'merges multiple named searches and ANDs their JQL' => [
        ["simple_string,simple_hash", nil], {jql: "(abc=123) AND (def=456)", max_results: 789}
      ],
      'returns a search with just JQL if given a query' => [
        ["foo='abc,def' and bar='waz'", nil], {jql: "(foo='abc,def' and bar='waz')"}
      ],
      'merges multiple named searches PLUS a JQL query' => [
        ["simple_string,simple_hash,hello=world", nil],
        {jql: "(abc=123) AND (def=456) AND (hello=world)", max_results: 789}
      ],
      'merges in a named output (jq array)' => [
        ["simple_string", "jq_array"], {jql: "(abc=123)", jq: %w[-cr .issues[].key]}
      ],
      'merges in a named output (hash)' => [
        ["simple_hash", "jq_hash"],
        {jql: "(def=456)", max_results: 200, fields: "key,summary", jq: %w[-c .issues[]]}
      ],
      'can use a default named output' => [
        ["with_default_output", nil], {jql: "(something=bla)", jq: ["-c"]}
      ],
      'treats empty string output name as nil output name (no/default output)' => [
        ["with_default_output", ""], {jql: "(something=bla)", jq: ["-c"]}
      ],
      'can override a default named output' => [
        ["with_default_output", "jq_array"], {jql: "(something=bla)", jq: %w[-cr .issues[].key]}
      ],
      "can override a default named output with an empty output" => [
        ["with_default_output", "all"], {jql: "(something=bla)"}
      ],
      "supports all config fields" => [
        ["all_config_fields", nil],
        {
          jql: "(a=1)", jq: ["-c"], max_results: 123, fields: "key",
          rendered_fields: true, api_version_3: true
        }
      ]
    }.each do |example_name, (args, expected_search)|
      it example_name do
        result = described_class.build(*args)
        expect(result).to be_a(Jir::SearchBuilder::Search)
        result = result.to_h.compact
        result[:jql] = result[:jql].jql
        expect(result).to eq(expected_search)
      end
    end
  end

  it 'raises an error if a named output is not found' do
    expect do
      described_class.build("foo=123", "bogus")
    end.to raise_error(/Output "bogus" not found in config file/)
  end

  it 'raises an error if a named output referenced by a named search is not found' do
    expect do
      described_class.build("search_with_unknown_output", nil)
    end.to raise_error(/Output "bogus" not found in config file/)
  end
end
