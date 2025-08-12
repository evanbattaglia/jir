require 'tabry/cli/base'
require_relative 'adf/renderer'
require_relative 'adf/text_to_adf'

module Jir
  class RenderCLI < Tabry::CLI::Base
    def text_to_adf
      puts TextToAdf.text_to_adf(STDIN.read).to_json
    end

    def raw
      each_file_json do |json|
        puts Adf::Renderer.render_adf_to_markdown(json)
      end
    end

    def ticket
      each_file_json do |json|
        json = JSON.parse(json)
        Adf::Renderer.puts_tickets_to_markdown(json)
      end
    end

    private

    def each_file_json
      if args.files&.any?
        args.files.each do |f|
          yield File.read(f)
        end
      else
        yield STDIN.read
      end
    end
  end
end
