# Represents JQL in the config which can take arguments
module Jir
  class Jql
    attr_reader :jql
    class WrongNumberOfArgs < StandardError; end

    # QUERY ARG FORMAT:
    # %1, %2, ... %10, %11, etc.
    # raw -- add 'r'., e.g. %1r
    # if you need to have a number (or r, s) directly after, use 's' to
    # separate, e.g. %1sr -> an arg plus 'r'
    QUERY_ARG_REGEX = /%([1-9]+)[sr]?/

    def initialize(jql)
      @jql = jql
    end

    # Join multiple queries into one query with ANDs between them.
    # If multiple queries have arguments (%1, %2, etc.), the numbers in them will be shifted up
    # to account for the previous queries' arguments.
    def self.join_queries_and_shift_args(queries)
      queries = queries.compact
      need_to_shift_by = [0]
      (1...queries.length).each do |i|
        need_to_shift_by[i] = need_to_shift_by[i-1] + n_args_in_query(queries[i-1])
      end
      queries.zip(need_to_shift_by).map do |query, shift_by|
        query = shift_query_args(query, shift_by)
        "(#{query})"
      end.join(" AND ")
    end

    def self.shift_query_args(query, shift_by)
      query.gsub(QUERY_ARG_REGEX) do |str|
        str.gsub($1, ($1.to_i + shift_by).to_s)
      end
    end

    def self.n_args_in_query(query)
      query.scan(QUERY_ARG_REGEX).map{ _1.first.to_i }.max || 0
    end

    def render(args)
      if args.to_a.length != n_args
        raise WrongNumberOfArgs,
          "Search requires #{n_args} arguments, got #{args.length}. Arguments: #{args.inspect}. Query: #{jql}"
      end
      sentinelized.gsub(QUERY_ARG_REGEX) do |str|
        # %1, %2, etc.
        # %r1 -> raw arg
        arg = args[$1.to_i - 1]
        arg = arg.to_json if !str.include?("r")
        arg
      end.gsub("\uFFFF", "%")
    end

    private
    def sentinelized
      @sentinelized ||= jql.gsub("%%", "\uFFFF")
    end

    def n_args
      sentinelized.scan(/%[1-9]/).sort.last&.[](-1).to_i
    end
  end
end


