# frozen_string_literal: true

module Unmagic
  module Components
    # The supported JSON Forms UI schema subset. Validate the whole tree before
    # rendering anything; options are never forwarded as arbitrary Rails helpers.
    class UISchema
      attr_reader :controls

      def initialize(schema, document)
        @schema = schema
        @controls = []
        @nodes = 0
        if document.nil?
          @controls = schema.properties.map { |property| { property: property, label: property.title, input_type: property.input_type } }
        else
          visit(document.is_a?(Hash) ? document.deep_stringify_keys : document, 0)
        end
      end

      private

      def invalid!(message)
        raise ArgumentError, "Unsupported UI schema: #{message}"
      end

      def keys!(object, allowed)
        invalid!("expected an object") unless object.is_a?(Hash)
        unknown = object.keys - allowed
        invalid!("unknown keys: #{unknown.join(', ')}") if unknown.any?
      end

      def visit(node, depth)
        @nodes += 1
        invalid!("exceeds 100 elements or 10 layout levels") if @nodes > 100 || depth > 10
        invalid!("expected an object") unless node.is_a?(Hash)
        case node["type"]
        when "VerticalLayout"
          keys!(node, %w[type elements])
          invalid!("VerticalLayout elements must be an array") unless node["elements"].is_a?(Array)
          node["elements"].each { |element| visit(element, depth + 1) }
        when "Control"
          control(node)
        else
          invalid!("unsupported element type #{node['type'].inspect}")
        end
      end

      def control(node)
        keys!(node, %w[type scope label options])
        scope = node["scope"]
        # Decode a single JSON Pointer segment, preserving literal / and ~ in keys.
        invalid!("scope must reference a flat property") unless scope.is_a?(String) && scope.match?(%r{\A\#/properties/(?:[^/~]|~[01])+\z})
        key = scope.delete_prefix("#/properties/").gsub("~1", "/").gsub("~0", "~")
        property = @schema.property(key)
        invalid!("unknown scope #{scope.inspect}") unless property
        invalid!("duplicate scope #{scope.inspect}") if @controls.any? { |item| item[:property].key == key }
        label = node.fetch("label", true)
        invalid!("label must be a string or boolean") unless label.is_a?(String) || label == true || label == false
        label = property.title if label == true
        options = node.fetch("options", {})
        keys!(options, %w[multi unmagic])
        if options.key?("multi") && ![ true, false ].include?(options["multi"])
          invalid!("multi must be a boolean")
        end
        unmagic = options.fetch("unmagic", {})
        keys!(unmagic, %w[widget])
        if unmagic.key?("widget") && unmagic["widget"] != "color"
          invalid!("unsupported unmagic widget #{unmagic['widget'].inspect}")
        end
        multi = options["multi"] == true
        color = unmagic["widget"] == "color"
        invalid!("multi and color cannot be combined") if multi && color
        if (multi || color) && (property.type != "string" || property.enum?)
          invalid!("multi and color require a non-enum string property")
        end
        input_type = multi ? :text_area : (color ? :color_field : property.input_type)
        @controls << { property: property, label: label, input_type: input_type }
      end
    end
  end
end
