require 'tabry/cli/base'
require 'tabry/cli/util'
require 'json'
require_relative 'api'
require_relative 'ticket_key_resolver'

module Jir
  class BaseCLI < Tabry::CLI::Base
    def inspect; end # Simplify backtraces

    private

    def jira(*arg, **kwargs)
      Api.jira(*arg, verbose: flags.verbose, dry_run: flags.dry_run, **kwargs)
    end

    def jira_json(*arg, **kwargs)
      JSON.parse(
        Api.jira(*arg, verbose: flags.verbose, dry_run: flags.dry_run, **kwargs, shell_method: :backtick_or_die)
      )
    end

    # Yields each result (parsed)
    def jira_json_each_page(url, extra=nil, extra_args=[], first_page_only: false, **kwargs, &)
      Api.jira_json_each_page(
        url, extra, extra_args, first_page_only:,
        verbose: flags.verbose,
        dry_run: flags.dry_run,
        **kwargs,
        &
      )
    end

    def ticket_key(key_string=args.ticket_key)
      TicketKeyResolver.ticket_key(key_string)
    end

    def ticket_keys(key_string=args.ticket_keys)
      TicketKeyResolver.ticket_keys(key_string)
    end

    def text_from_file_or_editor(filename)
      if filename
        File.read(filename)
      elsif $stdin.tty?
        Tempfile.open do |f|
          template =
          File.write(f.path, Config.creation_template)
          success = Tabry::CLI::Util.system("%s %s", ENV['EDITOR'], f.path)
          if success
            f.read
          else
            puts "Error: EDITOR returned non-zero status code. Operation aborted."
            exit 1
          end
        end
      else
        # TODO: support stdin -- it's getting attached to system() call and backtick when shelling out
        # to http. Actually need to fix that all over, and probably in Tabry::CLI::Util itself
        $stderr.puts "Filename with body required if STDIN is not a tty -- this is a TODO"
        exit 1
      end
    end
  end
end

