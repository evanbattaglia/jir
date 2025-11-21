require 'json'
require_relative 'base_cli'
require_relative 'config'

module Jir
  class IssueActionsCLI < BaseCLI
    def comment
      write_comment(text_from_file_or_editor(args.filename))
    end

    def transition
      transitions = JSON.parse(jira("issue/#{ticket_key}/transitions", shell_method: :backtick_or_die))
      transitions = transitions["transitions"].map{|t| {
        to_name: t["to"]["name"],
        transition_name: t["name"],
        id: t["id"]
      }}

      # First try to match by destination state name
      matching_by_state = transitions.select { |t| t[:to_name] == args.state_name }

      # If no match by state name, try to match by transition name
      if matching_by_state.empty?
        matching_by_transition = transitions.select { |t| t[:transition_name] == args.state_name }
        if matching_by_transition.length == 1
          jira "issue/#{ticket_key}/transitions", "transition[id]=%s", [matching_by_transition.first[:id]], method: :post
          return
        elsif matching_by_transition.empty?
          # Try numeric ID match as fallback
          matching_by_id = transitions.select { |t| t[:id] == args.state_name }
          if matching_by_id.length == 1
            jira "issue/#{ticket_key}/transitions", "transition[id]=%s", [matching_by_id.first[:id]], method: :post
            return
          end
        end
      end

      case matching_by_state.length
      when 0
        available_states = transitions.map { |t| t[:to_name] }.uniq
        available_transitions = transitions.map { |t| "#{t[:transition_name]} -> #{t[:to_name]}" }
        raise "No matching transition to #{args.state_name.inspect}. Available:\n" +
              "  States: #{available_states.join(', ')}\n" +
              "  Transitions: #{available_transitions.join(', ')}\n" +
              "  You can use state name, transition name, or transition ID"
      when 1
        jira "issue/#{ticket_key}/transitions", "transition[id]=%s", [matching_by_state.first[:id]], method: :post
      else
        puts "Multiple transitions to #{args.state_name.inspect}:"
        matching_by_state.each_with_index do |t, i|
          puts "  #{i + 1}. #{t[:transition_name]} -> #{t[:to_name]} (ID: #{t[:id]})"
        end
        puts
        puts "Please specify the transition by:"
        puts "  - Transition name: #{matching_by_state.map{|t| t[:transition_name]}.join(' | ')}"
        puts "  - Transition ID: #{matching_by_state.map{|t| t[:id]}.join(' | ')}"
        exit 1
      end
    end

    def assign
      if ['', 'null'].include?(args.user)
        jira "issue/#{ticket_key}/assignee", "accountId:=null", method: :put
      else
        jira "issue/#{ticket_key}/assignee", "accountId=%s", [Config.user(args.user)], method: :put
      end
    end

    def web
      ticket_keys.each do |key|
        Tabry::CLI::Util.open_web_page "#{Config.base_url}/browse/#{key}"
      end
    end

    def watchers__get = watchers_api
    def watchers__add = watchers_api("accountId=%s", [Config.user(args.user)])
    def watchers__remove = watchers_api("accountId==%s", [Config.user(args.user)], method: :delete)

    private

    def watchers_api(*args, **kwargs)
      jira "issue/#{ticket_key}/watchers", *args, api_version_3: true, **kwargs
    end

    def write_comment(body)
      body = body.strip

      if body.empty?
        puts "Error: empty body. Comment was not posted"
        exit 1
      end

      jira("issue/#{ticket_key}/comment", "body=%s", [body], method: :post)
    end
  end
end


