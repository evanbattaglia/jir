require_relative '../../../../lib/jir/adf/text_to_adf'

RSpec.describe Jir::TextToAdf do
  describe '.text_to_adf' do
    it 'converts simple paragraph to ADF' do
      text = "Hello world"
      result = described_class.text_to_adf(text)
      
      expect(result).to eq({
        type: "doc",
        version: 1,
        content: [
          {
            type: "paragraph",
            content: [{ type: "text", text: "Hello world" }]
          }
        ]
      })
    end

    it 'converts multiple paragraphs' do
      text = "First paragraph\nSecond paragraph"
      result = described_class.text_to_adf(text)
      
      expect(result[:content].length).to eq(2)
      expect(result[:content][0][:content][0][:text]).to eq("First paragraph")
      expect(result[:content][1][:content][0][:text]).to eq("Second paragraph")
    end

    it 'converts info panel' do
      text = "ℹ️ Information Panel\nContent inside panel"
      result = described_class.text_to_adf(text)
      
      panel = result[:content][0]
      expect(panel[:type]).to eq("panel")
      expect(panel[:attrs][:panelType]).to eq("info")
      expect(panel[:content].length).to eq(2)
      expect(panel[:content][0][:content][0][:text]).to eq("Information Panel")
      expect(panel[:content][1][:content][0][:text]).to eq("Content inside panel")
    end

    it 'converts success panel' do
      text = "✅ Success Panel\nPanel content"
      result = described_class.text_to_adf(text)
      
      panel = result[:content][0]
      expect(panel[:type]).to eq("panel")
      expect(panel[:attrs][:panelType]).to eq("success")
    end

    it 'converts simple bullet list' do
      text = "* Item 1\n* Item 2\n* Item 3"
      result = described_class.text_to_adf(text)
      
      list = result[:content][0]
      expect(list[:type]).to eq("bulletList")
      expect(list[:content].length).to eq(3)
      
      list[:content].each_with_index do |item, index|
        expect(item[:type]).to eq("listItem")
        expect(item[:content][0][:content][0][:text]).to eq("Item #{index + 1}")
      end
    end

    it 'converts nested bullet lists' do
      text = <<~TEXT
        * Outer item 1
          * Inner item 1
          * Inner item 2
        * Outer item 2
      TEXT
      
      result = described_class.text_to_adf(text)
      
      outer_list = result[:content][0]
      expect(outer_list[:type]).to eq("bulletList")
      expect(outer_list[:content].length).to eq(2)
      
      first_item = outer_list[:content][0]
      expect(first_item[:content].length).to eq(2) # Para + nested list
      
      nested_list = first_item[:content][1]
      expect(nested_list[:type]).to eq("bulletList")
      expect(nested_list[:content].length).to eq(2)
    end

    it 'converts code blocks without language' do
      text = <<~TEXT
        Regular paragraph
        ```
        function hello() {
          console.log("Hello");
        }
        ```
        Another paragraph
      TEXT
      
      result = described_class.text_to_adf(text)
      
      expect(result[:content].length).to eq(3)
      expect(result[:content][1][:type]).to eq("codeBlock")
      expect(result[:content][1][:content][0][:text]).to include("function hello()")
    end

    it 'converts code blocks with language' do
      text = <<~TEXT
        ```javascript
        const x = 42;
        ```
      TEXT
      
      result = described_class.text_to_adf(text)
      
      code_block = result[:content][0]
      expect(code_block[:type]).to eq("codeBlock")
      expect(code_block[:attrs][:language]).to eq("javascript")
      expect(code_block[:content][0][:text]).to eq("const x = 42;")
    end

    it 'handles code blocks inside panels' do
      text = <<~TEXT
        ℹ️ Code Example
        ```ruby
        puts "hello"
        ```
      TEXT
      
      result = described_class.text_to_adf(text)
      
      panel = result[:content][0]
      expect(panel[:type]).to eq("panel")
      expect(panel[:content].length).to eq(2)
      
      code_block = panel[:content][1]
      expect(code_block[:type]).to eq("codeBlock")
      expect(code_block[:attrs][:language]).to eq("ruby")
    end

    it 'skips empty lines appropriately' do
      text = <<~TEXT
        First paragraph

        Second paragraph


        Third paragraph
      TEXT
      
      result = described_class.text_to_adf(text)
      
      expect(result[:content].length).to eq(3)
      result[:content].each do |item|
        expect(item[:type]).to eq("paragraph")
      end
    end

    it 'handles mixed content structure' do
      text = <<~TEXT
        Introduction paragraph

        ℹ️ Important Information
        This is inside the info panel
        
        * First bullet point
        * Second bullet point
          * Nested point
        
        ✅ Success Criteria
        All tests must pass
        
        ```bash
        npm test
        ```
        
        Conclusion paragraph
      TEXT
      
      result = described_class.text_to_adf(text)
      
      # Should have: intro para, info panel, success panel
      expect(result[:content].length).to eq(3)
      
      types = result[:content].map { |item| item[:type] }
      expect(types).to eq(["paragraph", "panel", "panel"])
      
      # Info panel should contain the bullet list
      info_panel = result[:content][1]
      expect(info_panel[:attrs][:panelType]).to eq("info")
      info_content_types = info_panel[:content].map { |item| item[:type] }
      expect(info_content_types).to include("bulletList")
      
      # Success panel should contain the code block
      success_panel = result[:content][2]
      expect(success_panel[:attrs][:panelType]).to eq("success")
      success_content_types = success_panel[:content].map { |item| item[:type] }
      expect(success_content_types).to include("codeBlock")
    end

    it 'handles bullet list continuation lines' do
      text = <<~TEXT
        * First item
          Continuation of first item
        * Second item
      TEXT
      
      result = described_class.text_to_adf(text)
      
      list = result[:content][0]
      first_item = list[:content][0]
      
      # First item should have multiple paragraphs
      expect(first_item[:content].length).to be >= 2
    end

    it 'handles edge case with only panels' do
      text = <<~TEXT
        ℹ️ Panel 1
        Content 1
        
        ✅ Panel 2
        Content 2
      TEXT
      
      result = described_class.text_to_adf(text)
      
      expect(result[:content].length).to eq(2)
      expect(result[:content][0][:attrs][:panelType]).to eq("info")
      expect(result[:content][1][:attrs][:panelType]).to eq("success")
    end

    it 'handles empty input' do
      result = described_class.text_to_adf("")
      
      expect(result).to eq({
        type: "doc",
        version: 1,
        content: []
      })
    end

    it 'handles input with only whitespace' do
      result = described_class.text_to_adf("   \n  \n   ")
      
      expect(result).to eq({
        type: "doc",
        version: 1,
        content: []
      })
    end
  end
end

RSpec.describe Jir::TextToAdf::Para do
  describe '#initialize' do
    it 'strips whitespace from text' do
      para = described_class.new("  hello world  ")
      expect(para.as_json[:content][0][:text]).to eq("hello world")
    end

    it 'handles nil text' do
      para = described_class.new(nil)
      expect(para.as_json[:content][0][:text]).to be_nil
    end

    it 'accepts attributes' do
      para = described_class.new("text", marks: [{type: "strong"}])
      expect(para.as_json[:content][0][:marks]).to eq([{type: "strong"}])
    end
  end

  describe '#as_json' do
    it 'creates proper paragraph structure' do
      para = described_class.new("test text")
      result = para.as_json
      
      expect(result).to eq({
        type: "paragraph",
        content: [{type: "text", text: "test text"}]
      })
    end

    it 'includes attributes when present' do
      para = described_class.new("bold text", marks: [{type: "strong"}])
      result = para.as_json
      
      expect(result[:content][0][:marks]).to eq([{type: "strong"}])
    end
  end
end

RSpec.describe Jir::TextToAdf::Panel do
  describe '#initialize' do
    it 'creates panel with type and title' do
      panel = described_class.new("info", "Test Panel")
      result = panel.as_json
      
      expect(result[:type]).to eq("panel")
      expect(result[:attrs][:panelType]).to eq("info")
      expect(result[:content][0][:content][0][:text]).to eq("Test Panel")
      expect(result[:content][0][:content][0][:marks]).to eq([{type: "strong"}])
    end
  end
end

RSpec.describe Jir::TextToAdf::CodeBlock do
  describe '#initialize' do
    it 'creates code block with text only' do
      code = described_class.new("puts 'hello'")
      result = code.as_json
      
      expect(result[:type]).to eq("codeBlock")
      expect(result[:content][0][:text]).to eq("puts 'hello'")
      expect(result[:attrs]).to be_nil
    end

    it 'creates code block with language' do
      code = described_class.new("puts 'hello'", language: "ruby")
      result = code.as_json
      
      expect(result[:type]).to eq("codeBlock")
      expect(result[:attrs][:language]).to eq("ruby")
    end
  end
end
