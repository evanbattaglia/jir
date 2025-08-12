require 'tempfile'
require_relative 'config'
require_relative 'field_types'

module Jir
  class SearchCLI < BaseCLI
    # TODO:
    def search
      search = SearchBuilder.build(args.name_or_query, args.output)
      opts = {search_args: args.search_args, use_default_project: !flags.global}
      if flags.all_pages
        paginate_all do |start_at, raw_dest|
          execute_search(search, **opts, start_at: start_at, tee: raw_dest)
        end
      else
        execute_search(search, **opts)
      end
    end

    # TODO this is quite a hack, should just load the raw stuff into memory
    # instead of tee-ing. it's just annoying to push what's in memory to jq...
    def paginate_all
      start_at = 0
      loop do
        raw = Tempfile.open do |f|
          f.close
          yield start_at, f.path
          JSON.parse(File.read(f))
        end
        start_at += raw['maxResults']
        break if start_at > raw['total']
      end
    end

    def qualify_jql(clause, existing_jql)
      if existing_jql&.length > 1
        "#{clause} and (#{existing_jql})"
      else
        clause
      end
    end

    def execute_search(search, start_at: 0, tee: nil, max_results: nil, search_args: nil, use_default_project:)
      max_results ||= flags.max_results || search&.max_results || -1
      fields = flags.fields || search&.fields
      rendered_fields = flags.rendered_fields || search&.rendered_fields
      api_version_3 = flags.api_version_3 || search&.api_version_3
      order = flags.order || search&.order
      sprint = flags.sprint || search&.sprint
      # todo calculate these all for one search

      jql = search.jql.render(search_args)

      if Config.default_project && use_default_project
        jql = qualify_jql("project=#{Config.default_project.to_json}", jql)
      end

      if sprint
        sprint = Api.get_named_sprint(sprint)
        jql = qualify_jql("sprint=#{sprint['id']}", jql)
      end

      if order.to_s != ''
        jql += " ORDER BY #{order}"
      end
      extra = 'jql==%s maxResults==%s startAt==%s'
      extra_args = [jql, max_results, start_at]

      if fields
        # Lookup field aliases:
        fields = fields.split(",").map { |name| Config.field(name) }.map{ |f| f.key }.join(",")
        extra << ' fields==%s'
        extra_args << fields
      end

      extra << ' expand==renderedFields' if rendered_fields

      if tee
        extra << " | tee %s"
        extra_args << tee
      end

      if (jq = search&.jq)
        jq = [jq].flatten
        extra << " | jq " + ("%s " * jq.count)
        extra_args += jq
      end

      if search&.glow || flags.glow
        extra << " | jir render ticket | glow -p -"
      elsif search&.render_to_markdown || flags.render_to_markdown
        # TODO: super hack...
        extra << " | jir render ticket"
      end

      pipe = search&.pipe || flags.pipe
      extra << " | #{pipe}" if pipe

      jira 'search', extra, extra_args, api_version_3: api_version_3
    end

    def get
      search = SearchBuilder.build("key=%1", args.output)
      execute_search(search, max_results: 1, search_args: [ticket_key], use_default_project: false)
    end
  end
end


