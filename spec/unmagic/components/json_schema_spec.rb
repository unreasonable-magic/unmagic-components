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
    expect(instance.errors[:name]).to include("is required")
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
end
