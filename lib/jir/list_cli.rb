require_relative 'base_cli'
require_relative 'config'
require_relative 'builtin_configs'
require_relative 'field_types'

module Jir
  class ListCLI < BaseCLI
    STANDARD_FIELDS = %w[assignee description parent status summary]

    # These are mainly used for tab completion

    def searches
      print_completion_options_for_comma_separated_list(Config.searches.keys)
    end

    def outputs
      puts Config.outputs.keys
    end

    def fields
      fields = Config.fields_names.to_a + STANDARD_FIELDS
      if flags.autocomplete_commas
        print_completion_options_for_comma_separated_list(fields)
      else
        puts fields
      end
    end

    def field_types
      {
        **FieldTypes::FIELD_TYPE_STRING_TO_JSON_FUNCTIONS,
        **FieldTypes::FIELD_TYPE_STRING_ARRAY_TO_OBJECT_ARRAY_FUNCTIONS
      }.keys.each { |type| puts type }
    end

    def config
      puts Config.config.to_yaml
    end

    def builtin_configs
      puts BuiltinConfigs.names
    end

    def users
      puts Config.user_names
    end

    def state_names
      puts Config.state_names
    end

    # Takes an array and prints it out; but looks at the current_token in TABRY_AUTOCOMPLETE_STATE.
    # If it is a string that ends with a comma, it adds everything but the comma into the options,
    # so you can type "foo,a<tab>" and it will show all options starting with "a"
    def print_completion_options_for_comma_separated_list(array)
      current_token = JSON.parse(ENV['TABRY_AUTOCOMPLETE_STATE'])['current_token'] rescue ''
      current_token ||= ''
      prefix = current_token.sub(/[^,]*$/, '')
      already_in_list = current_token.split(",")
      (array - already_in_list).each{|item| puts "#{prefix}#{item}"}
    end

    def issue_types
      jira(
        "issue/createmeta", "projectKeys==%s | jq .projects[0].issuetypes[].name -r",
        [args.project || Config.default_project]
      )
    end

    def link_verbs
      jira_json("issueLinkType")['issueLinkTypes'].each do |link|
        puts link['inward']
        puts link['outward']
      end
    end

    def named_sprints
      puts Config.sprints.keys
    end

    def ticket_aliases
      puts Config.ticket_aliases.keys
    end
  end
end
