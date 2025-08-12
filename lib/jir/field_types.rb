require_relative 'ticket_key_resolver'

module Jir
  module FieldTypes
    module_function

    # For field types that can only take one value, this turns a string value into JSON
    # TODO: probably add descriptions for documentation
    FIELD_TYPE_STRING_TO_JSON_FUNCTIONS = {
      raw: -> (str) { str },
      string: -> (str) { str.to_json },
      # TODO should probably make more generic, any object with wrapper, but
      # that would require an extra parameter "object_key" or something which
      # would need to be given on the command line for use with --type...
      # then could remove user_list and use object_key=accountId and aliases: users
      object_keyed_by_name: -> (str) { {name: str}.to_json },
      object_keyed_by_key: -> (str) { {key: str}.to_json },
      ticket: -> str { {key: TicketKeyResolver.ticket_key(str)}.to_json },
    }
    # For field types that can take multiple values, the string values will be fed to this first
    # to make a JSON array. These return an array, not JSON, because for adding/removing items
    # from a list the JIRA API syntax uses each item wrapped in an {"add":<the thing>} object
    FIELD_TYPE_STRING_ARRAY_TO_OBJECT_ARRAY_FUNCTIONS = {
      user_list: -> (strs) { strs.map{|name| {accountId: Config.user(name)}} },
      string_list: -> (strs) { strs },
    }

    def resolve_aliases(aliases_type, value)
      return value unless aliases_type
      Config.aliases&.dig(aliases_type, value) || value
    end

    def field_values_array(type:, aliases_type:, values:)
      fn = FIELD_TYPE_STRING_ARRAY_TO_OBJECT_ARRAY_FUNCTIONS[type]
      if fn
        values = [] if values == [''] # special case -- empty array
        values = values.map { |v| resolve_aliases(aliases_type, v) }
        fn.call(values)
      end
    end

    def field_values_json(type:, aliases_type:, values:)
      json = field_values_array(type:, aliases_type:, values:)&.to_json

      if values.length == 1
        single_string_converter = FIELD_TYPE_STRING_TO_JSON_FUNCTIONS[type]
        value = resolve_aliases(aliases_type, values.first)
        json ||= single_string_converter&.call(value)
      end

      if !json
        raise "No type converter available for type #{type} for #{values.length} arguments"
      end

      json
    end
  end
end

