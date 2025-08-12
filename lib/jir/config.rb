require 'tabry/cli/util/config'

module Jir
  module Config
    VALID_AUTH_BACKENDS = %w[sshcrypt-pass pass gopass env]
    VALID_AUTH_TYPES = %w[basic bearer digest]

    Field = Struct.new(:key, :type, :aliases, keyword_init: true)

    class << self
      def config_dir
        @config_dir ||= "#{Dir.home}/.config/jir"
      end

      def config
        @config ||= merge_configs(Dir["#{config_dir}/*.yml"].map{|f| YAML.load_file(f)})
      end

      # Returns string or null
      def default_project
        config["default_project"] or raise "No default_project defined"
      end

      def default_board_id
        config["default_board_id"]
      end

      def searches
        config["searches"]
      end

      def sprints
        config["sprints"]
      end

      def outputs
        config["outputs"]
      end

      def fields_names
        config["fields"].keys
      end

      # Returns a Field object. if field not found in config, result will have name as "key"
      def field(name)
        Field.new(**(config['fields'][name] || {key: name}))
      end

      def user_names
        (config['users'] || {}).keys
      end

      def state_names
        config['state_names'] || []
      end

      # Returns a string (accountId)
      def user(name)
        name ||= 'default'
        config.dig('users', name) or raise "Unknown user #{name}"
      end

      def ticket_aliases
        config['ticket_aliases'] || {}
      end

      def aliases
        config['aliases']
      end

      def base_url
        config['base_url'] || config_error("missing base_url. example: https://mycompany.atlassian.net")
      end

      def creation_template
        config['creation_template'] ||
          "Warning -- text here will not be saved if the JIRA operation is unsuccessful (TODO)"
      end

      def auth_backend
        config['auth_backend'].tap do |val|
          unless VALID_AUTH_BACKENDS.include?(val)
            config_error "expected auth_backend to be set to one: #{VALID_AUTH_BACKENDS}, was: #{val}"
          end
        end
      end

      def auth_path
        config['auth_path']
      end

      def auth_type
        (config['auth_type'] || 'basic').tap do |val|
          unless VALID_AUTH_TYPES.include?(val)
            config_error "expected auth_type to be set to one: #{VALID_AUTH_TYPES}, was: #{val}"
          end
        end
      end

      def render_extra_jq
        config.dig('render', 'extra', 'jq')
      end

      private

      def merge_configs(configs)
        aliases = configs.map { _1['aliases'] }
        configs_without_aliases = configs.map { _1.except('aliases') }

        inner_merge_configs(configs_without_aliases)
          .merge('aliases' => inner_merge_configs(aliases))
      end

      def inner_merge_configs(configs)
        configs.each_with_object({}) do |subconfig, result|
          subconfig&.each do |key, val|
            existing_val = result[key]
            if existing_val.nil?
              result[key] = val
            elsif existing_val.class != result[key].class
              raise "Cannot merge config files, incompatible types for #{key.inspect}: #{existing_val.class}, #{result[key].class}"
            elsif existing_val.is_a?(Hash)
              result[key].merge! val
            elsif existing_val.is_a?(Array)
              result[key].concat val
            else
              result[key] = val
            end
          end
        end
      end

      def config_error(err)
        STDERR.puts "CONFIG ERROR in jir.yml: #{err}"
        exit 1
      end
    end
  end
end
