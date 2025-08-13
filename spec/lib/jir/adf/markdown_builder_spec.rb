require_relative '../../../../lib/jir/adf/markdown_builder'

RSpec.describe Jir::Adf::MarkdownBuilder do
  let(:builder) { described_class.new }

  describe '#initialize' do
    it 'starts with empty result and lists' do
      expect(builder.result).to eq('')
    end
  end

  describe '#concat' do
    it 'appends strings to result' do
      builder.concat('hello')
      builder.concat(' world')
      expect(builder.result).to eq('hello world')
    end

    it 'handles nil values gracefully' do
      builder.concat('test')
      builder.concat(nil)
      builder.concat('more')
      expect(builder.result).to eq('testmore')
    end
  end

  describe '#open_mark and #close_mark' do
    it 'handles link marks' do
      mark = { 'type' => 'link', 'attrs' => { 'href' => 'https://example.com' } }
      builder.open_mark(mark)
      builder.concat('text')
      builder.close_mark(mark)
      expect(builder.result).to eq('[text](https://example.com)')
    end

    it 'handles emphasis marks' do
      mark = { 'type' => 'em' }
      builder.open_mark(mark)
      builder.concat('emphasized')
      builder.close_mark(mark)
      expect(builder.result).to eq(' _emphasized_')
    end

    it 'handles strong marks' do
      mark = { 'type' => 'strong' }
      builder.open_mark(mark)
      builder.concat('bold')
      builder.close_mark(mark)
      expect(builder.result).to eq(' **bold**')
    end

    it 'handles strike marks' do
      mark = { 'type' => 'strike' }
      builder.open_mark(mark)
      builder.concat('struck')
      builder.close_mark(mark)
      expect(builder.result).to eq(' ~~struck~~')
    end

    it 'handles code marks' do
      mark = { 'type' => 'code' }
      builder.open_mark(mark)
      builder.concat('code')
      builder.close_mark(mark)
      expect(builder.result).to eq('`code`')
    end

    it 'handles underline marks like emphasis' do
      mark = { 'type' => 'underline' }
      builder.open_mark(mark)
      builder.concat('underlined')
      builder.close_mark(mark)
      expect(builder.result).to eq(' _underlined_')
    end

    it 'warns about unknown mark types' do
      mark = { 'type' => 'unknown_mark' }
      expect($stderr).to receive(:puts).with(/WARNING: unsupported mark type unknown_mark/).twice
      builder.open_mark(mark)
      builder.close_mark(mark)
    end
  end

  describe '#open_node and #close_node' do
    it 'handles heading nodes' do
      node = { 'type' => 'heading' }
      builder.open_node(node)
      builder.concat('Title')
      builder.close_node(node)
      expect(builder.result).to eq("# Title\n")
    end

    it 'handles code blocks' do
      node = { 'type' => 'codeBlock' }
      builder.open_node(node)
      builder.concat('console.log("hello")')
      builder.close_node(node)
      expect(builder.result).to eq("```\nconsole.log(\"hello\")\n```\n")
    end

    it 'handles blockquotes' do
      node = { 'type' => 'blockquote' }
      builder.open_node(node)
      builder.concat('quoted text')
      builder.close_node(node)
      expect(builder.result).to eq("> quoted text\n")
    end

    it 'handles paragraphs' do
      node = { 'type' => 'paragraph' }
      builder.open_node(node)
      builder.concat('paragraph text')
      builder.close_node(node)
      expect(builder.result).to eq("paragraph text\n\n")
    end

    it 'handles bullet lists' do
      list_node = { 'type' => 'bulletList' }
      item_node = { 'type' => 'listItem' }
      
      builder.open_node(list_node)
      builder.open_node(item_node)
      builder.concat('item 1')
      builder.close_node(item_node)
      builder.open_node(item_node)
      builder.concat('item 2')
      builder.close_node(item_node)
      builder.close_node(list_node)
      
      expect(builder.result).to eq("\t* item 1\t* item 2")
    end

    it 'handles ordered lists' do
      list_node = { 'type' => 'orderedList' }
      item_node = { 'type' => 'listItem' }
      
      builder.open_node(list_node)
      builder.open_node(item_node)
      builder.concat('first')
      builder.close_node(item_node)
      builder.close_node(list_node)
      
      expect(builder.result).to eq("\t1. first")
    end

    it 'handles nested lists with proper indentation' do
      outer_list = { 'type' => 'bulletList' }
      inner_list = { 'type' => 'bulletList' }
      item_node = { 'type' => 'listItem' }
      
      builder.open_node(outer_list)      # Level 0
      builder.open_node(item_node)       # Item at level 0
      builder.concat('outer item')
      builder.open_node(inner_list)      # Level 1
      builder.open_node(item_node)       # Item at level 1
      builder.concat('inner item')
      builder.close_node(item_node)
      builder.close_node(inner_list)
      builder.close_node(item_node)
      builder.close_node(outer_list)
      
      expect(builder.result).to eq("\t* outer item\t\t* inner item")
    end

    it 'handles panel with different types' do
      info_panel = { 'type' => 'panel', 'attrs' => { 'panelType' => 'info' } }
      warning_panel = { 'type' => 'panel', 'attrs' => { 'panelType' => 'warning' } }
      success_panel = { 'type' => 'panel', 'attrs' => { 'panelType' => 'success' } }
      error_panel = { 'type' => 'panel', 'attrs' => { 'panelType' => 'error' } }
      
      builder.open_node(info_panel)
      builder.concat('info')
      builder.close_node(info_panel)
      
      builder.open_node(warning_panel)
      builder.concat('warning')
      builder.close_node(warning_panel)
      
      builder.open_node(success_panel)
      builder.concat('success')
      builder.close_node(success_panel)
      
      builder.open_node(error_panel)
      builder.concat('error')
      builder.close_node(error_panel)
      
      expect(builder.result).to eq("---\ninfo---\n---\nwarning---\n---\nsuccess---\n---\nerror---\n")
    end

    it 'warns about unknown node types' do
      node = { 'type' => 'unknown_node' }
      expect($stderr).to receive(:puts).with(/WARNING: unsupported node type unknown_node/).twice
      builder.open_node(node)
      builder.close_node(node)
    end
  end

  describe '#inline' do
    it 'handles text nodes' do
      node = { 'type' => 'text', 'text' => 'some text' }
      builder.inline(node)
      expect(builder.result).to eq('some text')
    end

    it 'handles emoji nodes' do
      node = { 'type' => 'emoji', 'text' => '😀' }
      builder.inline(node)
      expect(builder.result).to eq('😀')
    end

    it 'handles hard breaks' do
      node = { 'type' => 'hardBreak' }
      builder.inline(node)
      expect(builder.result).to eq("\n\n")
    end

    it 'handles inline cards' do
      node = { 'type' => 'inlineCard', 'attrs' => { 'url' => 'https://example.com' } }
      builder.inline(node)
      expect(builder.result).to eq(' 📍 https://example.com')
    end

    it 'handles mentions' do
      node = { 'type' => 'mention', 'attrs' => { 'text' => 'John Doe' } }
      builder.inline(node)
      expect(builder.result).to eq('**John Doe**')
    end

    it 'warns about unknown inline types' do
      node = { 'type' => 'unknown_inline' }
      expect($stderr).to receive(:puts).with(/WARNING: unsupported inline type unknown_inline/)
      builder.inline(node)
    end
  end

  describe '#inline_extension' do
    it 'handles paste-code-macro extensions' do
      node = {
        'type' => 'extension',
        'attrs' => {
          'extensionType' => 'com.atlassian.confluence.macro.core',
          'extensionKey' => 'paste-code-macro',
          'parameters' => {
            'language' => 'javascript',
            'macroParams' => {
              '__bodyContent' => {
                'value' => 'console.log("hello");'
              }
            }
          }
        }
      }
      
      builder.inline(node)
      expect(builder.result).to eq("\n```javascript\nconsole.log(\"hello\");\n```\n\n")
    end

    it 'handles paste-code-macro without body content' do
      node = {
        'type' => 'extension',
        'attrs' => {
          'extensionType' => 'com.atlassian.confluence.macro.core',
          'extensionKey' => 'paste-code-macro',
          'parameters' => { 'language' => 'ruby' }
        }
      }
      
      expect($stderr).to receive(:puts).with(/WARNING: unsupported inline_extension type paste-code-macro without _bodyContent.value/)
      builder.inline(node)
    end

    it 'warns about unknown extensions' do
      node = {
        'type' => 'extension',
        'attrs' => {
          'extensionType' => 'unknown.extension',
          'extensionKey' => 'unknown-key'
        }
      }
      
      expect($stderr).to receive(:puts).with(/WARNING: unsupported inline_extension type unknown.extension\/unknown-key/)
      builder.inline(node)
    end
  end

  describe 'text prefixes' do
    it 'adds and concatenates text prefixes' do
      builder.add_text_prefix('>> ')
      builder.add_text_prefix('** ')
      
      node = { 'type' => 'text', 'text' => 'prefixed text' }
      builder.inline(node)
      
      expect(builder.result).to eq('>> ** prefixed text')
    end

    it 'clears text prefixes after concatenation' do
      builder.add_text_prefix('prefix: ')
      
      node1 = { 'type' => 'text', 'text' => 'first' }
      node2 = { 'type' => 'text', 'text' => 'second' }
      
      builder.inline(node1)
      builder.inline(node2)
      
      expect(builder.result).to eq('prefix: firstsecond')
    end
  end

  describe 'integrated examples' do
    it 'builds complex markdown structure' do
      # Simulate: # Title\nHello **world**!
      
      builder.open_node({ 'type' => 'heading' })
      builder.inline({ 'type' => 'text', 'text' => 'Title' })
      builder.close_node({ 'type' => 'heading' })
      
      builder.open_node({ 'type' => 'paragraph' })
      builder.inline({ 'type' => 'text', 'text' => 'Hello ' })
      builder.open_mark({ 'type' => 'strong' })
      builder.inline({ 'type' => 'text', 'text' => 'world' })
      builder.close_mark({ 'type' => 'strong' })
      builder.inline({ 'type' => 'text', 'text' => '!' })
      builder.close_node({ 'type' => 'paragraph' })
      
      expect(builder.result).to eq("# Title\nHello  **world**!\n\n")
    end
  end
end
