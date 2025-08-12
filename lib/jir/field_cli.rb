require_relative 'config'
require_relative 'field_types'

module Jir
  class FieldCLI < BaseCLI
    def set
      jira(
        "issue/#{ticket_key}",
        "fields[%s]:=%s",
        [field.key, field_values_json],
        method: :put,
        api_version_3: true,
      )
    end

    def add
      field_add_remove(:add)
    end

    def remove
      field_add_remove(:remove)
    end

    private

    def field
      @@field ||= Config.field(args.field)
    end

    def field_values_type
      @field_values_type ||= (flags.type || field.type || :string).to_sym
    end

    def field_values_aliases_type
      @field_values_aliases_type = field.aliases
    end

    def field_values_array
      FieldTypes.field_values_array(
        type: field_values_type,
        aliases_type: field_values_aliases_type,
        values: args.field_values,
      )
    end

    def field_values_json
      FieldTypes.field_values_json(
        type: field_values_type,
        aliases_type: field_values_aliases_type,
        values: args.field_values,
      )
    end

    def field_add_remove(add_or_remove)
      vals = field_values_array or raise "Cannot add/remove items for type #{field_values_type}"
      json = vals.map{|val| {add_or_remove => val}}.to_json
      jira(
        "issue/#{ticket_key}",
        "update[%s]:=%s",
        [field.key, json],
        method: :put
      )
    end
  end
end


