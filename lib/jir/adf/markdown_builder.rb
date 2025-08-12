# borrowed heavily from https://github.com/ankitpokhrel/jira-cli/blob/3ac9347b1839c98b025fdc000282982e1009c4c0/pkg/adf/markdown.go

module Jir
  module Adf
    #
    # TODO
    # top-level:
    #  heading
    #  mediaGroup
    #  mediaSingle
    #  rule
    #  table
    #
    # child:
    #  media
    #  table_cell
    #  table_header
    #  table_row
    #
    # marks:
    #   subsup
    #   textColor
    #   underline
    #
    class MarkdownBuilder
      attr_reader :result

      def initialize
        @result = ''
        @lists = []
      end

      def concat(str)
        @result << str if str
      end

      def warn_unknown(what, type)
        $stderr.puts "WARNING: unsupported #{what} type #{type}"
      end

      def add_text_prefix(prefix)
        @text_prefixes ||= ''
        @text_prefixes += prefix
      end

      def concat_text_prefixes
        return unless @text_prefixes
        concat @text_prefixes
        @text_prefixes = nil
      end

      def open_mark(mark)
        case mark['type']
        when 'link'
          concat '['
        when 'em', 'underline'
          concat ' _'
        when 'strong'
          concat ' **'
        when 'strike'
          concat ' ~~'
        when 'code'
          concat '`'
        else
          warn_unknown :mark, mark['type']
        end
      end

      def close_mark(mark)
        case mark['type']
        when 'link'
          concat "](#{mark.dig('attrs', 'href')})"
        when 'em', 'underline'
          concat '_'
        when 'strong'
          concat '**'
        when 'strike'
          concat '~~'
        when 'code'
          concat '`'
        else
          warn_unknown :mark, mark['type']
        end
      end

      def open_node(node)
        case node['type']
        when 'heading'
          concat '# '
        when 'doc'
        when 'codeBlock'
          concat "```\n"
        when 'blockquote'
          concat "> "
        when 'orderedList'
          @lists << :ordered
        when 'bulletList'
          @lists << :bullet
        when 'listItem'
          concat("\t" * @lists.length)
          concat(@lists&.last == :ordered ? '1. ' : '* ')
        when 'panel'
          concat "---\n"
          case node.dig('attrs', 'panelType')
          when 'info' then add_text_prefix("ℹ️  ")
          when 'warning' then add_text_prefix("⚠️  ")
          when 'success' then add_text_prefix("🙌 ")
          when 'error' then add_text_prefix("⛔ ")
          end
        when 'paragraph'
        else
          warn_unknown :node, node['type']
        end
      end

      def close_node(node)
        case node['type']
        when 'heading'
          concat "\n"
        when 'codeBlock'
          concat "\n```\n"
        when 'blockquote'
          concat "\n"
        when 'bulletList', 'orderedList'
          @lists.pop
        when 'doc'
        when 'listItem'
        when 'panel'
          concat "---\n"
        when 'paragraph'
          concat(@lists.empty? ? "\n\n" : "\n")
        else
          warn_unknown :node, node['type']
        end
      end

      def inline_extension(node)
        type = node.dig('attrs', 'extensionType')
        key = node.dig('attrs', 'extensionKey')
        if type == 'com.atlassian.confluence.macro.core' && key == "paste-code-macro"
          body = node.dig('attrs', 'parameters', 'macroParams', '__bodyContent', 'value')
          if body
            concat "\n```"
            concat node.dig('attrs', 'parameters', 'language')
            concat "\n"
            concat body
            concat "\n```\n\n"
          else
            warn_unknown :inline_extension, "paste-code-macro without _bodyContent.value"
          end
        else
          warn_unknown :inline_extension, "#{type}/#{key}"
        end
      end

      def inline(node)
        if node['type'] == 'extension'
          inline_extension(node)
          return
        end

        case node['type']
        when 'emoji'
          concat node['text']
        when 'text'
          concat_text_prefixes
          concat node['text']
        when 'hardBreak'
          concat "\n\n"
        when 'inlineCard'
          concat " 📍 "
          concat node.dig('attrs', 'url')
        when 'mention'
          concat '**'
          concat node.dig('attrs', 'text')
          concat '**'
        else
          warn_unknown :inline, node['type']
        end
      end
    end
  end
end


