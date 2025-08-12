require_relative 'walker'
require_relative 'markdown_builder'
require 'tabry/cli/util'

module Jir
  module Adf
    module Renderer
      module_function
      def render_adf_to_markdown(json)
        Walker.new(json, MarkdownBuilder).translate
      end

      def puts_extra(json)
        return unless Config.render_extra_jq
        Tempfile.open('jir_render.json') do |f|
          f.write(json.to_json)
          Tabry::CLI::Util.system("jq %s < %s", Config.render_extra_jq, f.path)
        end
      end

      def puts_tickets_to_markdown(json)
        json = json.dig('issues') || [json]
        json.each do |ticket|
          key = ticket['key']
          ticket = ticket['fields'] || ticket
          summary = ticket['summary']
          desc = ticket['description']
          comments = ticket.dig('comment', 'comments') || ticket.dig('comments')
          attachments = ticket['attachment']
          puts
          puts "# #{key}: #{summary}"

          puts

          if (parent = ticket['parent'])
            p_key = parent.dig('key')
            p_summary = parent.dig('fields', 'summary')
            p_type = parent.dig('fields', 'issuetype', 'name')
            puts "* Parent [#{p_type}]: #{p_key} #{p_summary}"
          end

          # TODO these should include installation-specific custom
          puts "* Assignee: #{ticket.dig('assignee', 'displayName') || '[none]'}"
          puts "* Reporter: #{ticket.dig('reporter', 'displayName') || '[none]'}"
          puts "* Status: #{ticket.dig('status', 'name')}"
          puts

          if desc
            puts "## Description"
            render_field(desc, "description")
            puts
          end

          puts_extra(json)

          if comments
            comments = JSON.parse(comments) if comments.is_a?(String)
            puts "## Comments"
            puts
            comments.reverse.each do |comment|
              author = comment.dig('author', 'displayName')
              created = comment['created']
              updated = comment['updated']
              print "### #{author} -- #{created}"
              if updated && updated != created
                print " (updated #{updated})"
              end
              puts
              render_field(comment['body'], "comment body")
            end
          end
          if attachments && !attachments.empty?
            attachments = JSON.parse(attachments) if attachments.is_a?(String)
            puts
            puts "## Attachments"
            puts
            attachments.reverse.each do |attachment|
              author = attachment.dig('author', 'displayName')
              filename = attachment['filename']
              created = attachment['created']
              content = attachment['content']
              size = attachment['size']
              puts "* #{filename} (#{size} bytes)"
              puts "  by #{author} on #{created}"
              puts "  link: #{content}"
              puts
            end
          end
        end
      end

      def render_field(data, name)
        if data.is_a?(String) && !data.start_with?('{"')
          raise "#{name} seems to be non-JSON text; did you use version 3 of the API?"
        end
        puts render_adf_to_markdown(data)
      end
    end
  end
end

