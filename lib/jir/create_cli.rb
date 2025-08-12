require 'json'
require_relative 'base_cli'
require_relative 'config'
require_relative 'adf/text_to_adf'

module Jir
  class CreateCLI < BaseCLI
    def main
      description = text_from_file_or_editor(flags.description_file)

      httpie_args = %w(
        fields[project][key]=%s
        fields[summary]=%s
        fields[issuetype][name]=%s
      )
      use_json_desc = !!flags.json_description || !!flags.pretty_description
      desc_field = use_json_desc ? "fields[description]:=%s" : "fields[description]=%s"
      if flags.pretty_description
        description = TextToAdf.text_to_adf(description).to_json
      end
      httpie_args << desc_field

      httpie_params = [
        args.project || Config.default_project,
        args.summary,
        args.issue_type,
        description,
      ]

      each_field_key_and_json_value do |key, json_value|
        httpie_args << "fields[%s]:=%s"
        httpie_params.concat [key, json_value]
      end

      jira(
        "issue",
        httpie_args.join(" "),
        httpie_params,
        api_version_3: use_json_desc,
        method: :post,
      )
    end

    private

    def split_field_to_name_and_values(field_str)
      field_value = field_str.dup.gsub!(/([^=]*)=/, '')
      if field_value.to_s == ''
        raise "Expected field_name=field_value_or_values: #{field_str.inspect}"
      end
      field_name = $1
      field_values = field_value.split(",")
      [field_name, field_values]
    end

    def each_field_key_and_json_value
      args.fields.each do |field_str|
        field_name, field_values = split_field_to_name_and_values(field_str)
        field = Config.field(field_name)

        values_json = FieldTypes.field_values_json(
          type: field.type&.to_sym || :string,
          values: field_values,
          aliases_type: field.aliases,
        )

        yield [field.key, values_json]
      end
    end
  end
end


