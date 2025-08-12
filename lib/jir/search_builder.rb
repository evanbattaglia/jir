require_relative 'config'
require_relative 'jql'

module Jir
  module SearchBuilder
    Search = Struct.new(
      :jql, :jq, :max_results, :fields, :rendered_fields, :api_version_3,
      :order,
      :sprint,
      :render_to_markdown, :glow, :pipe,
      keyword_init: true
    )

    class << self
      # merges the search and output, and returns an Search object
      def build(query, output_name)
        searches = decode_query_to_searches(query)
        search = merge_searches(searches)
        default_output_name = search.delete("output")

        output_name = nil if output_name == ""
        output_name ||= default_output_name
        search.merge!(named_output(output_name)) if output_name

        search["jql"] = Jql.new(search["jql"])
        Search.new(**search)
      end

      private

      # A search query can be:
      # * One or more named searches separated by a comma
      # * One or more named searches separated by a comma, followed by a jql
      #   query without any commas
      # * One jql query which can have commas
      def decode_query_to_searches(query)
        parts = query.split(",")
        named_searches = parts.map { |part| named_search(part) }

        if named_searches.none?(&:nil?)
          named_searches
        elsif parts.length > 1 && named_searches.last.nil? && named_searches.count(&:nil?) == 1
          [*named_searches.compact, {"jql" => parts.last}]
        else
          [{"jql" => query}]
        end
      end

      def merge_searches(searches)
        anded_jql = Jql.join_queries_and_shift_args(searches.map{|s| s["jql"]})
        searches.inject(&:merge).merge("jql" => anded_jql)
      end

      def named_search(search_name)
        make_hash(Config.searches[search_name], default_key: "jql")
      end

      def named_output(output_name)
        raw = Config.outputs[output_name]
        raise "Output #{output_name.inspect} not found in config file" unless raw
        make_hash(raw, default_key: "jq")
      end

      def make_hash(raw, default_key:)
        case raw
        when nil, Hash
          raw
        else
          {default_key => raw}
        end
      end
    end
  end
end
