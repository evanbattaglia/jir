require_relative 'base_cli'

module Jir
  class ChangelogCLI < BaseCLI
    def main
      # TODO paginate
      jira_json_each_page(
        "issue/#{ticket_key}/changelog", api_version_3: true,
        first_page_only: !flags.all_pages
      ) do |page|
        if flags.raw
          puts JSON.pretty_generate(page)
        else
          page['values'].each { _pretty_put_entry(_1) }
        end
      end
    end

    def _pretty_put_entry(entry)
      puts "#{entry['created']} -- #{entry.dig('author', 'displayName')}"
      entry['items'].each do |item|
        puts "  #{item['field']} #{item['fieldtype']} #{item['fromString']} -> #{item['toString']}"
      end
      puts
    end
  end
end
