# frozen_string_literal: true

RSpec.describe "code editor" do
  let(:view) { build_view }

  it "keeps escaped content, form attributes and the native fallback" do
    doc = html(view.code_editor_tag("query", "</textarea><script>alert(1)</script>", language: :graphql,
      schema: "type Query { value: String }", id: "query", required: true, class: "custom", aria: { label: "Query" }))
    root = doc.at("unmagic-code-editor")
    expect(root["language"]).to eq("graphql")
    expect(root["schema"]).to eq("type Query { value: String }")
    textarea = root.at("textarea")
    expect(textarea.text).to include("</textarea><script>alert(1)</script>")
    expect(doc.css("script")).to be_empty
    expect(textarea["id"]).to eq("query")
    expect(textarea["class"]).to include("custom")
    expect(textarea["required"]).not_to be_nil
    expect(textarea["aria-label"]).to eq("Query")
    expect(textarea["hidden"]).to be_nil
  end

  it "supports field labels and validation through the form builder" do
    signup = Signup.new.tap(&:validate)
    doc = html(build_form(signup) { |form| form.field :email, "Email", as: :code_editor, language: :json })
    textarea = doc.at("unmagic-code-editor textarea")
    expect(textarea["name"]).to eq("signup[email]")
    expect(textarea["aria-invalid"]).to eq("true")
    expect(doc.at("label")["for"]).to eq(textarea["id"])
  end

  it "supports blank, readonly and disabled fields" do
    doc = html(view.code_editor_tag("result", nil, readonly: true, disabled: true))
    expect(doc.at("unmagic-code-editor")["language"]).to eq("plaintext")
    expect(doc.at("textarea").text.strip).to eq("")
    expect(doc.at("textarea")["readonly"]).not_to be_nil
    expect(doc.at("textarea")["disabled"]).not_to be_nil
  end

  %i[javascript typescript python ruby html css sql java cpp go].each do |language|
    it "renders #{language} through the tag helper and form builder" do
      tag = html(view.code_editor_tag("source", "example", language: language))
      form = html(build_form { |builder| builder.code_editor(:name, language: language) })
      expect(tag.at("unmagic-code-editor")["language"]).to eq(language.to_s)
      expect(form.at("unmagic-code-editor")["language"]).to eq(language.to_s)
      expect(form.at("textarea")["name"]).to eq("signup[name]")
    end
  end

  it "rejects unknown languages" do
    expect { view.code_editor_tag("code", language: :not_a_language) }.to raise_error(ArgumentError, /unknown code editor language/)
  end

  it "disables preloads for every editor dependency after the general component pins" do
    pins = {}
    map = Object.new
    map.define_singleton_method(:pin) { |name, **options| pins[name] = options }
    map.define_singleton_method(:pin_all_from) do |path, under:, **options|
      Dir[File.join(path, "**/*.js")].each do |file|
        name = file.delete_prefix("#{path}/").delete_suffix(".js")
        pins["#{under}/#{name}"] = options
      end
    end
    file = File.expand_path("../../../config/importmap.rb", __dir__)
    map.instance_eval(File.read(file), file)
    heavy = pins.select { |name, _| name.start_with?("unmagic/components/code_editor/") }
    expect(heavy.size).to be > 20
    expect(heavy.values).to all(include(preload: false))
    expect(pins["unmagic/components/code_editor"]).to include(preload: true)
  end
end
