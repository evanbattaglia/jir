#!/usr/bin/env ruby
# frozen_string_literal: true

# EXPERIMENTAL ADF description builder for issue creation
# Rewritten from scratch (some AI code) but maybe should be based
# more on the MarkdownBuilder, to convert from real markdown.
#
# Para 1
# Para 2
# # Heading
# ℹ️ Description
# Foo with **bold**, _italic_, `code` and a [link](https://example.com)
# ✅ Acceptance Criteria
# * hello.
#   hello2
#   * bar1.
#     bar2
# * waz
# 1. first
# 2. second

module Jir
  module TextToAdf
    def self.text_to_adf(text)
      DocumentParser.new.parse(text).as_json
    end

    # Parses a single line of text into an array of ADF inline nodes,
    # handling **bold**, *italic*/_italic_, `code` and [text](url) links.
    module InlineParser
      SPLIT_REGEX = %r{
        (
          `[^`]+`                                              | # code
          \[[^\]]+\]\([^)]+\)                                  | # link
          \*\*(?=\S).+?(?<=\S)\*\*                             | # bold
          \*(?=\S)[^*]+?(?<=\S)\*                              | # italic *
          (?<![A-Za-z0-9_])_(?=\S)[^_]+?(?<=\S)_(?![A-Za-z0-9_]) # italic _
        )
      }x

      CODE_REGEX      = /\A`([^`]+)`\z/
      LINK_REGEX      = /\A\[([^\]]+)\]\(([^)]+)\)\z/m
      BOLD_REGEX      = /\A\*\*(.+)\*\*\z/m
      ITALIC_STAR_RE  = /\A\*([^*]+)\*\z/m
      ITALIC_US_RE    = /\A_(.+)_\z/m

      def self.parse(text, base_marks = [])
        return [] if text.nil? || text.empty?

        nodes = []
        text.split(SPLIT_REGEX).each do |segment|
          next if segment.nil? || segment.empty?

          if (m = segment.match(CODE_REGEX))
            nodes << text_node(m[1], base_marks + [{ type: "code" }])
          elsif (m = segment.match(LINK_REGEX))
            nodes << text_node(m[1], base_marks + [{ type: "link", attrs: { href: m[2] } }])
          elsif (m = segment.match(BOLD_REGEX))
            nodes.concat parse(m[1], base_marks + [{ type: "strong" }])
          elsif (m = segment.match(ITALIC_STAR_RE)) || (m = segment.match(ITALIC_US_RE))
            nodes.concat parse(m[1], base_marks + [{ type: "em" }])
          else
            nodes << text_node(segment, base_marks)
          end
        end
        nodes
      end

      def self.text_node(text, marks)
        node = { type: "text", text: text }
        node[:marks] = marks unless marks.empty?
        node
      end
    end

    class Node
      def children = @children ||= []
      def add_child(child) = children << child
      def as_json = raise("Unimplemented")
    end

    class Root < Node
      def as_json =
        {type: "doc", version: 1, content: children.map(&:as_json)}
    end

    # Represents a paragraph of text (with inline marks parsed from the text)
    class Para < Node
      attr_reader :attrs
      def initialize(text, attrs={})
        @text = text&.strip
        @attrs = attrs
      end

      def as_json
        marks = @attrs[:marks] || []
        content = InlineParser.parse(@text, marks)
        content = [base_text_node(marks)] if content.empty?
        {type: "paragraph", content: content}
      end

      private

      # Fallback node for nil/empty text so structure (and base marks) are preserved
      def base_text_node(marks)
        node = {type: "text"}
        node[:text] = @text unless @text.nil?
        node[:marks] = marks unless marks.empty?
        node
      end
    end

    # Represents a heading (# .. ######)
    class Heading < Node
      def initialize(text, level)
        @text = text&.strip
        @level = level
      end

      def as_json
        {
          type: "heading",
          attrs: {level: @level},
          content: InlineParser.parse(@text)
        }
      end
    end

    class Panel < Node
      def initialize(type, title)
        @type = type
        children << Para.new(title, marks: [{type: "strong"}])
      end

      def as_json =
        {
          type: "panel",
          attrs: {panelType: @type},
          content: children.map(&:as_json)
        }
    end

    # Represents a bullet list
    class BulletList < Node
      def as_json = { type: "bulletList", content: children.map(&:as_json) }
    end

    # Represents a numbered/ordered list
    class OrderedList < Node
      def as_json = { type: "orderedList", content: children.map(&:as_json) }
    end

    # Represents an item within a list
    class ListItem < Node
      def as_json = { type: "listItem", content: children.map(&:as_json) }
    end

    class CodeBlock < Node
      def initialize(text, language: nil)
        @text = text
        @language = language
      end

      def as_json
        json = {
          type: "codeBlock",
          content: [{type: "text", text: @text}]
        }
        json[:attrs] = {language: @language} if @language
        json
      end
    end

    class DocumentParser
      PANEL_REGEX = /^(ℹ️|✅)\s*(.*)$/
      HEADING_REGEX = /^(\#{1,6})\s+(.*)$/
      # Require a space after the '*' so a line like "**bold**" isn't read as a bullet
      BULLET_REGEX = /^(\s*)\*\s+(.*)$/
      ORDERED_REGEX = /^(\s*)\d+\.\s+(.*)$/
      INDENT_SPACES = 2 # Assuming 2 spaces per indent level for list items

      def parse(text)
        root = Root.new
        current_container = root # Tracks where new nodes should be added
        current_panel = nil
        bullet_stack = [] # To handle nested lists
        in_code_block = false
        code_block_lines = []
        code_block_language = nil

        text.lines.each do |line|
          stripped_line = line.strip
          if in_code_block
            if stripped_line == '```'
              in_code_block = false
              code_block_text = code_block_lines.join.chomp
              target_container = current_panel || root
              target_container.add_child(CodeBlock.new(code_block_text, language: code_block_language))
              code_block_lines = []
              code_block_language = nil
            else
              code_block_lines << line
            end
            next
          elsif (match = stripped_line.match(/^```(\S*)$/))
            in_code_block = true
            lang = match[1]
            code_block_language = lang unless lang.empty?
            bullet_stack.clear
            current_container = current_panel || root
            next
          end

          line.chomp! # Remove newline characters
          next if line.strip.empty? # Skip empty lines

          if (match = line.match(PANEL_REGEX))
            type_icon = match[1]
            title = match[2]
            panel_type = case type_icon
                         when '✅'
                           'success'
                         else 'ℹ️'
                           'info'
                         end
            new_panel = Panel.new(panel_type, title)
            root.add_child(new_panel)
            current_panel = new_panel
            current_container = new_panel # New nodes go into the panel
            bullet_stack.clear # Reset list state when a new panel starts
          elsif (match = line.match(HEADING_REGEX))
            level = match[1].length
            target_container = current_panel || root
            target_container.add_child(Heading.new(match[2], level))
            current_container = target_container
            bullet_stack.clear
          elsif (list_match = parse_list_line(line))
            add_list_item(list_match, bullet_stack, current_container) do |new_container|
              current_container = new_container
            end
          else
            # Handle regular paragraphs or continuation of list items
            if line.strip.empty?
              # Empty lines act as separators or end of blocks.
              # Reset current_container to the root for subsequent paragraphs
              # unless we are currently inside a list item that can have multiple paragraphs.
              current_container = current_panel || root
              bullet_stack.clear
              next
            end

            if current_container.is_a?(ListItem) && line.start_with?(' ' * (bullet_stack.last[:level] * INDENT_SPACES + INDENT_SPACES))
              # This line is indented and potentially part of the current list item's content.
              # We check if it's indented beyond the current list item's bullet level.
              # If it's a direct continuation, it's a Para inside the ListItem.
              current_container.add_child(Para.new(line))
            elsif current_container.is_a?(ListItem) && bullet_stack.last[:level] * INDENT_SPACES == line.index(/[^ ]/)
              # This line is at the same indentation level as the *previous* bullet
              # but not a bullet itself. It should be a new paragraph within the *same* list item.
              current_container.add_child(Para.new(line))
            else
              # This is a general paragraph, not part of a list continuation or a new bullet.
              # Reset bullet stack and add to the current panel or root.
              bullet_stack.clear
              target_container = current_panel || root
              target_container.add_child(Para.new(line))
              current_container = target_container # Ensure new paragraphs go to the correct top-level container
            end
          end
        end
        root
      end

      private

      # Returns {indent:, content:, type:} for a bullet/ordered list line, else nil
      def parse_list_line(line)
        if (match = line.match(BULLET_REGEX))
          {indent: match[1], content: match[2], type: :bullet}
        elsif (match = line.match(ORDERED_REGEX))
          {indent: match[1], content: match[2], type: :ordered}
        end
      end

      # Adds a list item to the appropriate (possibly new/nested) list, updating the
      # bullet_stack. Yields the new current_container (the created ListItem).
      def add_list_item(list_match, bullet_stack, current_container)
        level = list_match[:indent].length / INDENT_SPACES
        type = list_match[:type]

        # Pop deeper levels until we reach this item's level or shallower
        while !bullet_stack.empty? && bullet_stack.last[:level] > level
          bullet_stack.pop
        end

        new_parent = nil
        # Same level but a different list type starts a sibling list in the same parent
        if !bullet_stack.empty? && bullet_stack.last[:level] == level && bullet_stack.last[:type] != type
          new_parent = bullet_stack.last[:parent]
          bullet_stack.pop
        end

        if bullet_stack.empty? || bullet_stack.last[:level] < level
          parent = new_parent || current_container
          list_node = type == :ordered ? OrderedList.new : BulletList.new
          parent.add_child(list_node)
          bullet_stack << {list_node: list_node, level: level, type: type, parent: parent}
        end

        list_item = ListItem.new
        bullet_stack.last[:list_node].add_child(list_item)
        list_item.add_child(Para.new(list_match[:content]))
        yield list_item
      end
    end
  end
end
