require_relative '../../../../lib/jir/adf/walker'

RSpec.describe Jir::Adf::Walker do
  # Mock builder for testing
  class MockBuilder
    attr_reader :calls, :result

    def initialize
      @calls = []
      @result = "mock_result"
    end

    def open_node(node)
      @calls << [:open_node, node['type']]
    end

    def close_node(node)
      @calls << [:close_node, node['type']]
    end

    def open_mark(mark)
      @calls << [:open_mark, mark['type']]
    end

    def close_mark(mark)
      @calls << [:close_mark, mark['type']]
    end

    def inline(node)
      @calls << [:inline, node['type'], node['text']]
    end
  end

  describe '#initialize' do
    it 'accepts string JSON data' do
      walker = described_class.new('{"type": "doc"}', MockBuilder)
      expect(walker.doc).to eq({ "type" => "doc" })
    end

    it 'accepts hash data' do
      data = { "type" => "doc" }
      walker = described_class.new(data, MockBuilder)
      expect(walker.doc).to eq(data)
    end
  end

  describe '#translate' do
    it 'returns builder result' do
      walker = described_class.new({ "type" => "text", "text" => "hello" }, MockBuilder)
      result = walker.translate
      expect(result).to eq("mock_result")
    end

    context 'with inline node (no content)' do
      it 'calls inline method and handles marks' do
        data = {
          "type" => "text",
          "text" => "hello",
          "marks" => [{ "type" => "strong" }]
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_mark, "strong"],
          [:inline, "text", "hello"],
          [:close_mark, "strong"]
        ])
      end

      it 'processes inline node without marks' do
        data = { "type" => "text", "text" => "plain text" }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:inline, "text", "plain text"]
        ])
      end
    end

    context 'with container node (has content)' do
      it 'processes nested structure correctly' do
        data = {
          "type" => "paragraph",
          "content" => [
            {
              "type" => "text",
              "text" => "Hello ",
              "marks" => [{ "type" => "strong" }]
            },
            {
              "type" => "text", 
              "text" => "world"
            }
          ]
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_node, "paragraph"],
          [:open_mark, "strong"],
          [:inline, "text", "Hello "],
          [:close_mark, "strong"],
          [:inline, "text", "world"],
          [:close_node, "paragraph"]
        ])
      end

      it 'handles deeply nested structures' do
        data = {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
              "content" => [
                {
                  "type" => "text",
                  "text" => "nested"
                }
              ]
            }
          ]
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_node, "doc"],
          [:open_node, "paragraph"],
          [:inline, "text", "nested"],
          [:close_node, "paragraph"],
          [:close_node, "doc"]
        ])
      end

      it 'processes container with marks' do
        data = {
          "type" => "paragraph",
          "marks" => [{ "type" => "em" }],
          "content" => [
            { "type" => "text", "text" => "emphasized paragraph" }
          ]
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_node, "paragraph"],
          [:open_mark, "em"],
          [:inline, "text", "emphasized paragraph"],
          [:close_mark, "em"],
          [:close_node, "paragraph"]
        ])
      end
    end

    context 'with multiple marks' do
      it 'opens and closes marks in correct order' do
        data = {
          "type" => "text",
          "text" => "styled",
          "marks" => [
            { "type" => "strong" },
            { "type" => "em" }
          ]
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_mark, "strong"],
          [:open_mark, "em"],
          [:inline, "text", "styled"],
          [:close_mark, "em"],
          [:close_mark, "strong"]
        ])
      end
    end

    context 'with empty content' do
      it 'handles node with empty content array' do
        data = {
          "type" => "paragraph",
          "content" => []
        }
        
        walker = described_class.new(data, MockBuilder)
        walker.translate
        
        expect(walker.builder.calls).to eq([
          [:open_node, "paragraph"],
          [:close_node, "paragraph"]
        ])
      end
    end
  end
end
