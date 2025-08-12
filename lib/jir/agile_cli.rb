require_relative 'base_cli'
require 'date'

module Jir
  class AgileCLI < BaseCLI
    # TODO: pagination. just shows the first page.
    def boards
      jira("board", "projectKeyOrId==%s", [args.project || Config.default_project], api_agile: true)
    end

    def named_sprint
      puts JSON.pretty_generate(Api.get_named_sprint(args.name, all: !!flags.all))
    end

    # TODO: pagination. just shows the first page.
    def sprints
      board_id = args.board_id || Config.default_board_id || raise("No default_board_id in config")
      states = [
        ('active' unless flags.future_only),
        ('future' if flags.active_and_future || flags.future_only),
        ('closed' if flags.closed)
      ].compact

      jira_json_each_page(
        "board/#{board_id}/sprint",
        "state==%s",
        [states.join(",")],
        first_page_only: !flags.all_pages,
        api_agile: true
      ) do |json|
        if flags.summary
          # Show simplified view of id, state, name, startDate, endDate, state
          json['values'].each do |sprint|
            puts [
              sprint['id'],
              sprint['state'],
              sprint['name'],
              sprint['startDate'],
              sprint['endDate'],
              sprint['state']
            ].join("\t")
          end
        else
          puts JSON.pretty_generate(json)
        end
      end
    end

    def jira_agile_display(jira_args, **jira_kwargs, &display_block)
      if flags.all_pages
        jira_json_each_page(*jira_args, **jira_kwargs) do |json|
          display_block.call(json)
        end
      end
    end

    def move_issue
      sprint_id = args.sprint_id
      sprint_name, sprint_url =
        case args.sprint_id
        when 'backlog'
          [nil, 'backlog']
        when /\A[1-9][0-9]+\z/
          [nil, "sprint/#{args.sprint_id}"]
        else
          named = Api.get_named_sprint(args.sprint_id, require_one: true)
          [named['name'], "sprint/#{named['id']}"]
        end

      if sprint_name
        puts "Moving into sprint: #{sprint_name}"
      end

      # TODO current, future maybe?
      extra = "issues:=%s"
      extra_args = [args.ticket_keys.map{|k| ticket_key(k)}.to_json]
      if flags.before_issue
        extra += " rankBeforeIssue=%s"
        extra_args += ticket_key(flags.before_issue)
      end
      if flags.after_issue
        extra += " rankAfterIssue=%s"
        extra_args += ticket_key(flags.after_issue)
      end
      jira("#{sprint_url}/issue", extra, extra_args, method: :post, api_agile: true)
    end

    def rank
      raise "Cannot use both --before and --after" if flags.after && flags.before
      ref_ticket = ticket_key(args.reference_ticket)
      ticket_keys = args.ticket_keys.map { |t| ticket_key(t) }

      ref_pos = flags.before ? "rankBeforeIssue" : "rankAfterIssue"

      jira(
        "issue/rank",
        "%s=%s issues:=%s", [ref_pos, ref_ticket, ticket_keys.to_json],
        method: :put, api_agile: true
      )
    end

    private
    def sprints_json(state)
      jira_json("board/#{Config.default_board_id}/sprint", "state==%s", [state.to_s], api_agile: true, dry_run: false)['values']
    end
  end
end
