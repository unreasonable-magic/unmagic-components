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

  def read_attribute_for_validation(attribute)
    self[attribute]
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

  def validation_error(error)
    definition = error["schema"]
    case error["type"]
    when "minLength" then [ :too_short, { count: definition["minLength"] } ]
    when "maxLength" then [ :too_long, { count: definition["maxLength"] } ]
    when "minimum" then [ :greater_than_or_equal_to, { count: definition["minimum"] } ]
    when "maximum" then [ :less_than_or_equal_to, { count: definition["maximum"] } ]
    when "exclusiveMinimum" then [ :greater_than, { count: definition["exclusiveMinimum"] } ]
    when "exclusiveMaximum" then [ :less_than, { count: definition["exclusiveMaximum"] } ]
    when "multipleOf" then [ :multiple_of, { count: definition["multipleOf"] } ]
    when "integer" then [ :not_an_integer, {} ]
    when "number" then [ :not_a_number, {} ]
    when "boolean" then [ :not_a_boolean, {} ]
    when "string" then [ :not_a_string, {} ]
    when "enum", "const" then [ :inclusion, {} ]
    else [ :invalid, {} ]
    end
  end

  def conform_to_schema
    JSONSchemer.schema(schema.document).validate(@values).each do |error|
      key = error["data_pointer"].to_s.delete_prefix("/").presence
      if error["type"] == "required"
        error.fetch("details").fetch("missing_keys").each { |name| errors.add(name, :blank) }
      else
        type, options = validation_error(error)
        errors.add(key&.gsub("~1", "/")&.gsub("~0", "~") || :base, type, **options)
      end
    end
  end
end
