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
        "color" => { "type" => "string", "default" => "#123456" },
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
    expect(doc.at('input[name="settings[color]"]')["value"]).to eq("#123456")
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
    expect(doc.at('input[name="settings[color]"]')["value"]).not_to eq("#123456")
    expect(doc.at('select option[selected]')["value"]).to eq("member")
  end

  it "renders property validation errors, including missing required values" do
    instance = Unmagic::Components::JSONSchema::Instance.new(schema, count: "oops", enabled: "maybe")
    expect(instance).not_to be_valid
    doc = fields(schema, instance)
    expect(doc.at('input[name="settings[count]"]')["aria-invalid"]).to eq("true")
    expect(doc.at('input[type="checkbox"]')["aria-invalid"]).to eq("true")
    expect(doc.at('select[name="settings[role]"]')["aria-invalid"]).to eq("true")
    expect(doc.css(".UnmagicError").map(&:text).join).to include("can't be blank", "must be an integer")
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

RSpec.describe "JSON Forms UI schema subset" do
  let(:schema) do
    { type: "object", required: [ "body" ], properties: {
      title: { type: "string", default: "Hello" },
      body: { type: "string", minLength: 3, default: "First\nSecond" },
      accent: { type: "string", default: "#123456" },
      enabled: { type: "boolean", default: false },
      role: { type: "string", enum: [ "admin", "member" ] }
    } }
  end

  def render_ui(ui, values = {})
    instance = Unmagic::Components::JSONSchema::Instance.new(schema, values)
    instance.valid?
    html(build_view.form_with(scope: :settings, model: instance, url: "/settings",
      builder: Unmagic::Components::FormBuilder) { |form| form.schema_fields(schema, ui_schema: ui) })
  end

  def control(key, **options)
    { type: "Control", scope: "#/properties/#{key}", **options }
  end

  it "renders ordered controls, multiline values and color using UI options" do
    ui = { type: "VerticalLayout", elements: [
      control(:body, label: "Message", options: { multi: true }),
      { type: "VerticalLayout", elements: [ control(:accent, options: { unmagic: { widget: "color" } }) ] }
    ] }
    doc = render_ui(ui)
    expect(doc.css('[data-field] label').map(&:text)).to eq([ "Message *", "Accent" ])
    expect(doc.at("textarea").text.strip).to eq("First\nSecond")
    expect(doc.at("textarea")["required"]).not_to be_nil
    expect(doc.at('input[type="color"]')["value"]).to eq("#123456")
    expect(doc.at('[name="settings[title]"]')).to be_nil
    invalid = render_ui(ui, body: "x")
    expect(invalid.at("textarea")["aria-invalid"]).to eq("true")
    expect(invalid.at("textarea").text.strip).to eq("x")
    expect(invalid.at(".UnmagicError")).not_to be_nil
  end

  it "keeps accessible names when labels are hidden for every control kind" do
    %w[title body enabled role].each do |key|
      doc = render_ui(control(key, label: false))
      input = doc.at('input:not([type="hidden"]), select, textarea')
      expect(input["aria-label"]).to eq(key.humanize)
      expect(doc.css("label")).to be_empty
    end
  end

  it "accepts JSON string keys and escapes custom labels and textarea contents" do
    doc = render_ui(JSON.parse(JSON.generate(control(:body, label: "<img>", options: { multi: true }))), body: "</textarea><script>x</script>")
    expect(doc.css("script, img")).to be_empty
    expect(doc.at("textarea").text).to include("</textarea><script>x</script>")
    expect(doc.at("label").text).to include("<img>")
  end

  it "resolves escaped JSON Pointer property names" do
    schema[:properties]["a/b~c"] = { type: "string", default: "escaped" }
    expect(render_ui(control("a~1b~0c")).at('input[type="text"]')["value"]).to eq("escaped")
  end

  it "rejects unsupported or ambiguous UI schemas before rendering" do
    invalid = [ false, {}, { type: "HorizontalLayout", elements: [] },
      { type: "VerticalLayout", elements: {} }, control(:missing),
      control("body/properties/nested"), control("bad~2escape"),
      control(:body, label: nil), control(:body, rule: {}),
      control(:body, options: { rows: 4 }), control(:body, options: { multi: "true" }),
      control(:body, options: { unmagic: { widget: "text_area" } }),
      control(:body, options: { multi: true, unmagic: { widget: "color" } }),
      control(:enabled, options: { multi: true }), control(:role, options: { unmagic: { widget: "color" } }),
      { type: "VerticalLayout", elements: [ control(:body), control(:body) ] } ]
    invalid.each do |ui|
      expect { render_ui(ui) }.to raise_error(ArgumentError, /Unsupported UI schema/)
    end
  end

  it "bounds layout recursion" do
    ui = control(:body)
    12.times { ui = { type: "VerticalLayout", elements: [ ui ] } }
    expect { render_ui(ui) }.to raise_error(ArgumentError, /layout levels/)
  end

  it "rejects the removed color format with migration guidance" do
    schema[:properties][:accent][:format] = "color"
    expect { render_ui(nil) }.to raise_error(ArgumentError, /use UI schema options.unmagic.widget: color/)
  end
end
