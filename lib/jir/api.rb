require_relative 'config'

module Jir
  module Api
    module_function

    def auth
      @auth ||=
        if Config.auth_backend == 'env'
          env_var_name = Config.auth_path || 'JIR_AUTH'
          ENV[env_var_name] or raise "No JIRA auth found in environment variable #{env_var_name}"
        else
          auth_path = Config.auth_path || 'jir'
          Tabry::CLI::Util.backtick_or_die("%s show %s", Config.auth_backend, auth_path).chomp
        end
    end

    def jira(
      url,
      extra=nil, extra_args=[],
      verbose:, dry_run:,
      api_version_3: false, api_agile: false, no_api: false,
      method: :get,
      shell_method: :system,
      extra_before: nil
    )
      api = no_api ? "" : api_agile ? "rest/agile/1.0/" : api_version_3 ? "rest/api/3/" : "rest/api/2/"
      # Not sure why --ignore-stdin is sometimes necessary but when running as
      # part of completion (maybe whenever stdin is not a tty) it seems to be
      # expecting (and waiting for) stdin, even for gets
      auth_type = Config.auth_type
      Tabry::CLI::Util.send(
        shell_method,
        "http --ignore-stdin #{extra_before} --auth-type %s -a %s %s %s/#{api}%s #{extra}",
        [auth_type, auth, method, Config.base_url, url] + extra_args,
        echo: verbose,
        echo_only: dry_run
      )
    end

    def jira_json_each_page(
      url,
      extra=nil, extra_args=[],
      first_page_only:,
      dry_run:,
      **kwargs,
      &
    )
      start = 0

      loop do
        json = jira(
          url,
          extra.to_s + " startAt==#{start}",
          extra_args,
          **kwargs,
          dry_run:,
          shell_method: :backtick_or_die
        )
        return if dry_run

        json = JSON.parse(json)
        yield json

        if first_page_only || !json['values'] || json['values'].length < json['maxResults']
          break
        else
          start += json['maxResults']
        end
      end
    end

    # Get a named sprint from the config
    def get_named_sprint(name, all: false, require_one: false)
      require 'open3'
      criteria = Config.sprints&.dig(name) or raise "No such sprint in config: #{name}"
      board_id = criteria['board_id'] || Config.default_board_id

      sprints = []
      jira_json_each_page(
        "board/#{Config.default_board_id}/sprint",
        "state==%s",
        [criteria['state'] || 'active'],
        first_page_only: !criteria['all_pages'],
        verbose: false, dry_run: false,
        api_agile: true
      ) do |json|
        sprints.concat json['values']
      end

      if criteria['jq']
        Open3.popen3("jq", "-c", criteria['jq']) do |stdin, out, err, _wait|
          stdin.write sprints.to_json
          stdin.close
          sprints = out.read.split("\n").map { JSON.parse _1 }
          err.read.strip&.then { STDERR.puts _1 if _1.length > 0 }
        end
      end

      sprints = [sprints].flatten
      if all
        sprints
      elsif require_one && sprints.length != 1
        raise "Expected exactly one sprint, got #{sprints.length} with names: #{sprints.map { _1['name'] }.to_json}"
      else
        sprints.first
      end
    end
  end
end
