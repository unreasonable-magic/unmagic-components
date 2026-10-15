# frozen_string_literal: true

module Unmagic
  module Components
    # Maps the supported schema properties onto the host's FormBuilder controls.
    class SchemaFields
      def initialize(form, template, schema)
        @form = form
        @template = template
        @schema = schema.is_a?(JSONSchema::Schema) ? schema : JSONSchema::Schema.new(schema)
        @schema.validate_form!
      end

      def render
        @template.safe_join(@schema.properties.map { |property| render_property(property) })
      end

      private

      def render_property(property)
        value = value_for(property)
        required = @schema.required?(property.key)
        options = {}
        if @form.object.respond_to?(:errors) && @form.object.errors[property.key].any?
          options["aria-invalid"] = "true"
        end

        if property.enum.present?
          @form.field(property.key, property.title, required: required, hint: property.description) do
            @form.select(property.key, property.enum.map { |item| [ item.to_s, item ] },
              { selected: value, include_blank: true }, options.merge(required: required))
          end
        elsif property.boolean?
          # A required JSON boolean can be false: HTML's required checkbox would
          # incorrectly force true. Rails' hidden input submits the unchecked value.
          @form.field(property.key, nil) do
            @form.check_box_field(property.key, property.title, hint: property.description,
              **options, checked: property.cast(value) == true)
          end
        else
          options[:step] = property.type == "number" ? "any" : 1 if %w[integer number].include?(property.type)
          @form.field(property.key, property.title, required: required, hint: property.description,
            as: property.input_type, value: value, **options)
        end
      end

      def value_for(property)
        object = @form.object
        if object.respond_to?(:key?) && object.respond_to?(:[])
          return @form.form_value_for(property.key) if object.key?(property.key) || object.key?(property.key.to_sym)
        elsif object.respond_to?(property.key)
          return @form.form_value_for(property.key)
        end
        property.default
      end
    end
  end
end
