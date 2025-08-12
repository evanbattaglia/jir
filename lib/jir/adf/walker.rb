module Jir
  module Adf
    class Walker
      attr_reader :doc, :builder, :builder_class

      def initialize(data, builder_class)
        @doc = data.is_a?(String) ? JSON.parse(data) : data
        @builder_class = builder_class
      end

      def translate
        @builder = builder_class.new
        walk_translate(doc)
        builder.result
      end

      def walk_translate(node)
        inline = !node['content']

        builder.open_node(node) unless inline
        node['marks']&.each { |m| builder.open_mark(m) }

        if inline
          builder.inline(node)
        else
          node['content'].each do |subnode|
            walk_translate(subnode)
          end
        end

        node['marks']&.each { |m| builder.close_mark(m) }
        builder.close_node(node) unless inline
      end
    end
  end
end
