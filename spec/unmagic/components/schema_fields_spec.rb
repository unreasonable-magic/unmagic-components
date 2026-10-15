# frozen_string_literal: true

RSpec.describe "Schema-driven forms" do
  let(:schema) do
    {
      "type" => "object", "required" => [ "name", "enabled", "role" ],
      "properties" => {
        "name" => { "type" => "string", "title" => "Display name", "description" => "Shown publicly", "default" => "Ada" },
        "enabled" => { "type" => "boolean", "default" => true },
        "count" => { "type" => "integer", "default" => 3 },
        "rate" => { "type" => "number", "default" => 1.5 },
        "color" => { "type" => "string", "format" => "color", "default" => "#123456" },
        "role" => { "type" => "string", "enum" => [ "admin", "member" ] },
        "region" => { "type" => "string", "enum" => [ "east", "west" ] }
      }
    }
  end

  def fields(schema, values = nil)
    view = build_view
    html(view.form_with(scope: :settings, url: "/settings", model: values || false,
      builder: Unmagic::Components::FormBuilder) { |form| form.schema_fields(schema) })
  end

  it "renders defaults, labels, hints, input types and required controls" do
    doc = fields(schema)
    expect(doc.at('input[name="settings[name]"]')["value"]).to eq("Ada")
    expect(doc.at('input[name="settings[name]"]')["required"]).to eq("required")
    expect(doc.at("label").text).to include("Display name")
    expect(doc.at(".UnmagicHint").text).to eq("Shown publicly")
    expect(doc.at('input[type="checkbox"]')["checked"]).to eq("checked")
    expect(doc.at('input[type="checkbox"]')["required"]).to be_nil
    expect(doc.at('input[name="settings[count]"]')["step"]).to eq("1")
    expect(doc.at('input[name="settings[rate]"]')["step"]).to eq("any")
    expect(doc.at('input[type="color"]')["value"]).to eq("#123456")
    expect(doc.at('select[name="settings[role]"]')["required"]).to eq("required")
    expect(doc.at('select[name="settings[role]"] option')["value"]).to eq("")
    expect(doc.at('select[name="settings[region]"] option')["value"]).to eq("")
  end

  it "preserves false, zero, empty and nil values instead of restoring defaults" do
    instance = Unmagic::Components::JSONSchema::Instance.new(schema, name: "", enabled: false, count: 0, color: nil, role: "member")
    doc = fields(schema, instance)
    expect(doc.at('input[name="settings[name]"]')["value"]).to eq("")
    expect(doc.at('input[type="checkbox"]')["checked"]).to be_nil
    expect(doc.at('input[name="settings[count]"]')["value"]).to eq("0")
    expect(doc.at('input[type="color"]')["value"]).not_to eq("#123456")
    expect(doc.at('select option[selected]')["value"]).to eq("member")
  end

  it "renders property validation errors, including missing required values" do
    instance = Unmagic::Components::JSONSchema::Instance.new(schema, count: "oops", enabled: "maybe")
    expect(instance).not_to be_valid
    doc = fields(schema, instance)
    expect(doc.at('input[name="settings[count]"]')["aria-invalid"]).to eq("true")
    expect(doc.at('input[type="checkbox"]')["aria-invalid"]).to eq("true")
    expect(doc.at('select[name="settings[role]"]')["aria-invalid"]).to eq("true")
    expect(doc.css(".UnmagicError").map(&:text).join).to include("is required", "must be a whole number")
  end

  it "escapes schema-supplied labels, hints, defaults and enum choices" do
    untrusted = { type: "object", properties: { title: { type: "string", title: "<script>x</script>", description: "<img src=x>", default: '<img src=x>' }, choice: { enum: [ '<script>x</script>' ] } } }
    doc = fields(untrusted)
    expect(doc.css("script, img")).to be_empty
    expect(doc.at("label").text).to eq("<script>x</script>")
  end

  it "rejects unsupported fields and unsafe parameter names before rendering" do
    [ { type: "object" }, { type: "array" }, { properties: { child: {} } }, { enum: [ {} ] }, { enum: [] }, { "$ref" => "#/other" }, { oneOf: [ { type: "string" } ] } ].each do |definition|
      expect { fields(type: "object", properties: { nested: definition }) }.to raise_error(ArgumentError, /Unsupported form schema/)
    end
    expect { fields(properties: { "a[b]" => { type: "string" } }) }.to raise_error(ArgumentError, /brackets/)
    expect { fields(properties: Array.new(51) { |i| [ "field#{i}", {} ] }.to_h) }.to raise_error(ArgumentError, /50 properties/)
  end

  it "renders an empty schema without theme-specific copy" do
    expect(fields({}).css("input:not([type=hidden]), select, .UnmagicField")).to be_empty
  end
end
