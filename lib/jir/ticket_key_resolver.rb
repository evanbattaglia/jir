module Jir
  module TicketKeyResolver
    module_function

    def ticket_key(key_string)
      tickets = ticket_keys(key_string).uniq
      if tickets.length != 1
        $stderr.puts "Error: multiple tickets given or found in git commits: #{tickets.to_json}"
        exit 1
      end
      tickets.first
    end

    def ticket_keys(key_string)
      if key_string.include?(",")
        return key_string.split(",").map { |k| ticket_keys(k) }.flatten
      end

      if key_string.empty?
        $stderr.puts "Error: empty ticket key given"
        exit 1
      end

      if key_string =~ /^[0-9]+$/ && Config.default_project
        ["#{Config.default_project}-#{key_string}"]
      elsif (from_alias = Config.ticket_aliases[key_string])
        [from_alias]
      elsif key_string =~ %r{^git([/:.@].*)?$} && Config.default_project
        git_ref = $1.to_s.gsub(%r{^[/:.]}, '')
        git_ref = 'HEAD' if git_ref == ''
        ticket_keys_from_git_ref(git_ref)
      elsif key_string =~ /[A-Z]+-[0-9]+/
        [key_string]
      else
        raise "Error: unknown ticket key format: #{key_string}"
      end
    end

    def ticket_keys_from_git_ref(ref)
      commit_msg = Tabry::CLI::Util.backtick_or_die("git log --format=%%B -n 1 %s", ref)
      ticket_regex = /(#{Regexp.escape Config.default_project}-[0-9]{1,8})(\W|$)/
      tickets = commit_msg.scan(ticket_regex).map(&:first)
      if tickets.empty?
        $stderr.puts "Error: cannot find ticket in project #{Config.default_project} in commit message for git ref #{ref}"
        exit 1
      end
      tickets
    end
  end
end
