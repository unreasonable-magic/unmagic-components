# frozen_string_literal: true

RSpec.describe Unmagic::Components::JSONSchema::Instance do
  let(:schema) do
    { type: "object", required: [ "name" ], properties: {
      name: { type: "string", minLength: 2 },
      count: { type: "integer", minimum: 0, default: 4 },
      rate: { type: "number" }, enabled: { type: "boolean" }, optional: { type: "string" }
    } }
  end

  it "coerces submitted primitives, applies defaults and omits absent optional values" do
    instance = described_class.new(schema, name: "Ada", rate: "1.25", enabled: "0")
    expect(instance).to be_valid
    expect(instance.to_h).to eq("name" => "Ada", "count" => 4, "rate" => 1.25, "enabled" => false)
  end

  it "does not turn invalid input into valid zeroes or truncate fractional integers" do
    [ "oops", "1.5", "2oops" ].each do |value|
      instance = described_class.new(schema, name: "Ada", count: value)
      expect(instance).not_to be_valid
      expect(instance.errors[:count]).not_to be_empty
    end
  end

  it "validates standard constraints and assigns required errors to their fields" do
    instance = described_class.new(schema, count: "-1")
    expect(instance).not_to be_valid
    expect(instance.errors[:name]).to include("can't be blank")
    expect(instance.errors[:count]).not_to be_empty
    expect(described_class.new(schema, name: "A")).not_to be_valid
  end

  it "retains a declared null default for an untyped property" do
    instance = described_class.new(properties: { optional: { default: nil } })
    expect(instance.to_h).to eq("optional" => nil)
    expect(instance).to be_valid
  end

  it "does not overwrite explicit nil or false with defaults" do
    instance = described_class.new(schema, name: "Ada", count: nil, enabled: false)
    expect(instance["count"]).to be_nil
    expect(instance["enabled"]).to eq(false)
    expect(instance).not_to be_valid
  end
  describe "translated errors" do
    around do |example|
      previous = I18n.backend
      locales = I18n.available_locales
      I18n.available_locales = [ :en, :fr ]
      I18n.backend = I18n::Backend::Simple.new
      I18n.t("errors.messages.invalid")
      example.run
    ensure
      I18n.backend = previous
      I18n.available_locales = locales
    end

    it "uses Rails error types and interpolation, with attribute overrides" do
      I18n.backend.store_translations(:en, {
        errors: { messages: { greater_than_or_equal_to: "Minimum: %{count}" } },
        activemodel: { errors: { models: {
          "unmagic/components/json_schema/instance" => { attributes: {
            name: { too_short: "Name needs %{count} characters" }
          } }
        } } }
      })
      instance = described_class.new(schema, name: "A", count: -1)
      expect(instance).not_to be_valid
      expect(instance.errors[:name]).to eq([ "Name needs 2 characters" ])
      expect(instance.errors[:count]).to eq([ "Minimum: 0" ])
      expect(instance.errors.details[:name]).to eq([ { error: :too_short, count: 2 } ])
      expect(instance.errors.full_messages).to include("Name Name needs 2 characters")
    end

    it "supplies defaults only for errors Rails does not provide" do
      instance = described_class.new({ properties: {
        enabled: { type: "boolean" }, name: { type: "string" }, rate: { type: "number", multipleOf: 0.5 }
      } }, enabled: "maybe", name: 123, rate: 1.25)
      expect(instance).not_to be_valid
      expect(instance.errors[:enabled]).to eq([ "must be true or false" ])
      expect(instance.errors[:name]).to eq([ "must be text" ])
      expect(instance.errors[:rate]).to eq([ "must be a multiple of 0.5" ])
      I18n.backend.store_translations(:en, errors: { messages: { not_a_boolean: "Choose yes or no" } })
      expect(instance.errors[:enabled]).to eq([ "Choose yes or no" ])
    end

    it "resolves messages using the current locale after validation" do
      I18n.backend.store_translations(:fr, errors: { messages: { blank: "est requis", not_a_boolean: "doit être un booléen" } })
      instance = described_class.new(schema, enabled: "maybe")
      expect(instance).not_to be_valid
      I18n.with_locale(:fr) do
        expect(instance.errors[:name]).to eq([ "est requis" ])
        expect(instance.errors[:enabled]).to eq([ "doit être un booléen" ])
      end
    end
  end
end
