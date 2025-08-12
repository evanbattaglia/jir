#!/usr/bin/env ruby
# frozen_string_literal: true

# EXPERIMENTAL ADF description builder for issue creation
# Rewritten from scratch (some AI code) but maybe should be based
# more on the MarkdownBuilder, to convert from real markdown.
#
# Para 1
# Para 2
# ℹ️ Description
# Foo
# ✅ Acceptance Criteria
# Bar
# * hello.
#   hello2
#   * bar1.
#     bar2
# * waz

module Jir
  module TextToAdf
    def self.text_to_adf(text)
      DocumentParser.new.parse(text).as_json
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

    # Represents a paragraph of text
    class Para < Node
      attr_reader :attrs
      def initialize(text, attrs={})
        @text = text&.strip
        @attrs = attrs
      end

      def as_json
        content = {type: "text", text: @text, **attrs}.compact
        {type: "paragraph", content: [content]}
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

    # Represents an item within a bullet list
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
      BULLET_REGEX = /^(\s*)\*\s*(.*)$/
      INDENT_SPACES = 2 # Assuming 2 spaces per indent level for bullets

      def parse(text)
        root = Root.new
        current_container = root # Tracks where new nodes should be added
        current_panel = nil
        bullet_stack = [] # To handle nested bullet lists
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
            bullet_stack.clear # Reset bullet list state when a new panel starts
          elsif (match = line.match(BULLET_REGEX))
            indent_str = match[1]
            content = match[2]
            current_indent_level = indent_str.length / INDENT_SPACES

            # Pop from stack until we find the parent level
            while !bullet_stack.empty? && bullet_stack.last[:level] > current_indent_level
              bullet_stack.pop
            end

            # If we need a new list (first item, or deeper nesting).
            # The parent for a new list is the current container (root, panel, or a ListItem for nesting).
            if bullet_stack.empty? || bullet_stack.last[:level] < current_indent_level
              new_bullet_list = BulletList.new
              current_container.add_child(new_bullet_list)
              bullet_stack << { list_node: new_bullet_list, level: current_indent_level }
            end

            current_list_node = bullet_stack.last[:list_node]
            new_list_item = ListItem.new
            current_list_node.add_child(new_list_item)
            new_list_item.add_child(Para.new(content)) # Bullet content is a Para
            current_container = new_list_item # Future indented lines become children of this ListItem
          else
            # Handle regular paragraphs or continuation of bullet items
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
    end
  end
end
