# frozen_string_literal: true

# An "instance" of a JSON Schema: the schema paired with a set of values, behaving
# like an ActiveModel object so it drops straight into form_with and the
# FormBuilder. Values are coerced to their declared type, defaulting to the
# schema default; to_h is the coerced set, and
# validation reports values that violate the schema, keyed per property.
class Unmagic::Components::JSONSchema::Instance
  include ActiveModel::Model

  validate :conform_to_schema

  attr_reader :schema

  # Hash-ish reads, so a caller can treat the instance like the value hash it stands
  # in for (e.g. settings["accent_color"]). [] and to_h are below.
  delegate :each, :keys, :values, :fetch, :key?, :dig, :merge, :empty?, to: :to_h

  def initialize(schema, values = {})
    @schema = schema.is_a?(Unmagic::Components::JSONSchema::Schema) ? schema : Unmagic::Components::JSONSchema::Schema.new(schema)
    @schema.validate_form!
    @values = resolve(values)
  end

  def to_h
    @values
  end

  def [](key)
    @values[key.to_s]
  end

  private

  # An unset property with no default is omitted (absent ≠ null in JSON Schema), so
  # an optional typed setting isn't reported as a nil that violates its type. Accepts
  # a hash or another instance (its coerced values) as the source.
  def resolve(values)
    given = (values || {}).to_h.stringify_keys
    schema.properties.each_with_object({}) do |property, resolved|
      if given.key?(property.key)
        resolved[property.key] = property.cast(given[property.key])
      elsif property.default?
        resolved[property.key] = property.cast(property.default)
      end
    end
  end

  def validation_message(error)
    definition = error["schema"]
    case error["type"]
    when "minLength" then "must be at least #{definition['minLength']} characters"
    when "maxLength" then "must be at most #{definition['maxLength']} characters"
    when "minimum" then "must be at least #{definition['minimum']}"
    when "maximum" then "must be at most #{definition['maximum']}"
    when "integer" then "must be a whole number"
    when "number" then "must be a number"
    when "boolean" then "must be true or false"
    when "enum" then "is not one of the available choices"
    else "is invalid"
    end
  end

  def conform_to_schema
    JSONSchemer.schema(schema.document).validate(@values).each do |error|
      key = error["data_pointer"].to_s.delete_prefix("/").presence
      if error["type"] == "required"
        error.fetch("details").fetch("missing_keys").each { |name| errors.add(name, "is required") }
      else
        errors.add(key&.gsub("~1", "/")&.gsub("~0", "~") || :base, validation_message(error))
      end
    end
  end
end
