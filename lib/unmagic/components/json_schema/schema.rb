# frozen_string_literal: true

# A parsed JSON Schema (draft 2020-12) for an `object`: its ordered properties and
# the raw document, which JSONSchemer validates values against.
class Unmagic::Components::JSONSchema::Schema
  MAX_FORM_PROPERTIES = 50
  MAX_FORM_KEY_LENGTH = 128
  SUPPORTED_FORM_ROOT_TYPES = [ nil, "object" ].freeze
  SUPPORTED_FORM_PROPERTY_TYPES = [ nil, "string", "boolean", "integer", "number" ].freeze

  attr_reader :document

  def initialize(document)
    @source = document
    @document = document.is_a?(Hash) ? document.deep_stringify_keys : {}
  end

  def validate_form!
    errors = form_errors
    raise ArgumentError, "Unsupported form schema: #{errors.join(", ")}" if errors.any?

    self
  end

  def properties
    properties_document.map { |key, definition| Unmagic::Components::JSONSchema::Property.new(key, definition) }
  end

  # The property keys, in document order — like ActiveRecord's attribute_names.
  def property_names
    properties.map(&:key)
  end

  def form_errors
    errors = []
    properties = form_properties

    errors << "must be a JSON object" unless @source.nil? || @source.is_a?(Hash)
    errors << "must be an object schema" if SUPPORTED_FORM_ROOT_TYPES.exclude?(@document["type"])
    errors << "properties must be a JSON object" if @document.key?("properties") && !@document["properties"].is_a?(Hash)
    errors << "contains more than #{MAX_FORM_PROPERTIES} properties" if properties_document.size > MAX_FORM_PROPERTIES

    invalid_property_definitions.each do |name|
      errors << "contains invalid property definition for #{name.inspect}"
    end

    properties.map(&:key).each do |name|
      if (error = form_key_error(name))
        errors << "contains unsupported property name #{name.inspect} (#{error})"
      end
    end

    unsupported_property_types(properties).each do |property|
      errors << "contains unsupported property type #{property.type.inspect} for #{property.key.inspect}"
    end

    invalid_enum_properties(properties).each do |property|
      errors << "contains invalid enum for #{property.key.inspect}"
    end

    [ @document, *form_properties_document.map(&:last).select { |value| value.is_a?(Hash) } ].each do |definition|
      unsupported = definition.keys & %w[$ref $dynamicRef allOf anyOf oneOf not if then else dependentSchemas]
      errors << "contains unsupported form keywords: #{unsupported.join(', ')}" if unsupported.any?
    end

    form_properties_document.each do |name, definition|
      next unless definition.is_a?(Hash)
      if definition["format"] == "color"
        errors << "format: color was removed; use UI schema options.unmagic.widget: color for #{name.inspect}"
      end
      if (definition.keys & %w[properties patternProperties items prefixItems]).any?
        errors << "contains nested fields for #{name.inspect}"
      end
    end

    errors << "required must be an array" if @document.key?("required") && !@document["required"].is_a?(Array)
    errors
  end

  def property(key)
    properties.find { |property| property.key == key.to_s }
  end

  # The property keys the schema marks required; the rest may be left blank.
  def required
    @document["required"].is_a?(Array) ? @document["required"] : []
  end

  def required?(key)
    required.include?(key.to_s)
  end

  delegate :any?, to: :properties

  private

  def properties_document
    @document["properties"].is_a?(Hash) ? @document["properties"] : {}
  end

  def invalid_property_definitions
    form_properties_document.filter_map do |key, definition|
      key.to_s unless definition.is_a?(Hash)
    end
  end

  def form_key_error(name)
    name = name.to_s
    return "is blank" if name.blank?
    return "is too long" if name.length > MAX_FORM_KEY_LENGTH
    return "cannot end with ?" if name.end_with?("?")

    "cannot contain brackets or control characters" if name.match?(/[\[\]\p{Cc}]/)
  end

  def unsupported_property_types(properties)
    properties.reject { |property| SUPPORTED_FORM_PROPERTY_TYPES.include?(property.type) }
  end

  def invalid_enum_properties(properties)
    properties.select do |property|
      property.enum? && (!property.enum.is_a?(Array) || property.enum.empty? ||
        property.enum.any? { |value| ![ String, Numeric, TrueClass, FalseClass ].any? { |type| value.is_a?(type) } })
    end
  end

  def form_properties
    form_properties_document.map { |key, definition| Unmagic::Components::JSONSchema::Property.new(key, definition) }
  end

  def form_properties_document
    properties_document.first(MAX_FORM_PROPERTIES + 1)
  end
end
