# frozen_string_literal: true

# One property of a JSON Schema object: its key (the schema's property name) and
# the subschema describing it. Exposes the bits a form and a coercer need, maps the
# declared type to a FormBuilder input, and casts a raw value to that type.
class Unmagic::Components::JSONSchema::Property
  attr_reader :key

  def initialize(key, definition)
    @key = key.to_s
    @definition = definition.is_a?(Hash) ? definition : {}
  end

  def type = @definition["type"]
  def format = @definition["format"]
  def description = @definition["description"]
  def default? = @definition.key?("default")
  def default = @definition["default"]
  def enum = @definition["enum"]
  def enum? = @definition.key?("enum")

  def title
    @definition["title"].presence || @key.humanize
  end

  def boolean? = type == "boolean"

  # The FormBuilder input (`as:`) for this property. Booleans render as a
  # checkbox and enums as a select, so they don't come through here.
  def input_type
    if format == "color"
      :color_field
    elsif type == "integer" || type == "number"
      :number_field
    else
      :text_field
    end
  end

  # Coerces a raw value (e.g. a form string) to this property's declared type.
  def cast(value)
    return value if value.nil?

    case type
    when "boolean"
      return true if [ true, "true", "1", 1 ].include?(value)
      return false if [ false, "false", "0", 0 ].include?(value)
      value
    when "integer", "number"
      return value unless value.is_a?(String)
      # Parse JSON numbers, not Ruby's permissive casts ("oops" must not become 0).
      parsed = JSON.parse(value)
      parsed.is_a?(Numeric) ? parsed : value
    else
      value
    end
  rescue JSON::ParserError
    value
  end
end
