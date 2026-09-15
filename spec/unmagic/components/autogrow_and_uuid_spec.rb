# frozen_string_literal: true

RSpec.describe "autogrow textareas and uuid inputs" do
  let(:view) { build_view }
  let(:uuid_v7) { /\A\h{8}-\h{4}-7\h{3}-[89ab]\h{3}-\h{12}\z/ }

  describe "FormBuilder#autogrow_text_area" do
    it "wraps the builder's textarea in the element" do
      doc = html(build_form { |form| form.autogrow_text_area(:name, rows: 2) })

      textarea = doc.at("unmagic-autogrow.UnmagicAutogrow > textarea")
      expect(textarea["name"]).to eq("signup[name]")
      expect(textarea["rows"]).to eq("2")
    end

    # Rails' default field_error_proc wraps an invalid control in a div, which
    # lands inside the element, so the textarea is a descendant rather than a child.
    it "works as a field's control, keeping the label, error and invalid state" do
      signup = Signup.new.tap(&:validate)
      doc = html(build_form(signup) { |form| form.field :email, "Email", as: :autogrow_text_area })

      field = doc.at(".UnmagicField")
      textarea = field.at("unmagic-autogrow textarea")
      expect(textarea["name"]).to eq("signup[email]")
      expect(textarea["aria-invalid"]).to eq("true")
      expect(field.at("label").text).to eq("Email")
      expect(field.at(".UnmagicError").text).to eq("can't be blank")
    end
  end

  describe "#autogrow_text_area_tag" do
    it "wraps text_area_tag" do
      textarea = html(view.autogrow_text_area_tag("note", "Hello", rows: 3)).at("unmagic-autogrow > textarea")

      expect([ textarea["name"], textarea["rows"], textarea.text.strip ]).to eq([ "note", "3", "Hello" ])
    end

    it "styles the textarea like the builder's, keeping the caller's class" do
      textarea = html(view.autogrow_text_area_tag("note", class: "font-mono")).at("textarea")

      expect(textarea["class"]).to eq("UnmagicInput font-mono")
    end
  end

  describe "FormBuilder#uuid_field" do
    it "renders the element around a hidden field holding a UUIDv7" do
      doc = html(build_form { |form| form.uuid_field(:id) })

      element = doc.at("unmagic-uuid-input")
      expect(element["name"]).to eq("signup[id]")

      input = element.at("> input[type=hidden]")
      expect(input["name"]).to eq("signup[id]")
      expect(input["id"]).to be_nil
      expect(input["value"]).to match(uuid_v7)
    end

    it "mints a different id for each render" do
      ids = Array.new(2) { html(build_form { |form| form.uuid_field(:id) }).at("input[name='signup[id]']")["value"] }

      expect(ids.uniq.size).to eq(2)
    end
  end

  describe "#uuid_input_tag" do
    it "renders a hidden field by name, outside a form builder" do
      input = html(view.uuid_input_tag("message[id]")).at("unmagic-uuid-input[name='message[id]'] > input")

      expect(input["name"]).to eq("message[id]")
      expect(input["value"]).to match(uuid_v7)
    end
  end
end
