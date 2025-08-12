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
      transitions = transitions["transitions"].map{|t| {name: t["to"]["name"], id: t["id"]}}
      matching = transitions.select { |t| t[:name] == args.state_name }
      case matching.length
      when 0
        raise "No matching transition to #{args.state_name.inspect} for this ticket. Possible end states: #{transitions.map { |t| t[:name] }}"
      when 1
        jira "issue/#{ticket_key}/transitions", "transition[id]=%s", [matching.first[:id]], method: :post
      else
        raise "Multiple transitions to #{args.state_name.inspect}: #{matching.map{|t| t[:id]}}"
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


