# frozen_string_literal: true

RSpec.describe Unmagic::Components::FormBuilder do
  describe "#field" do
    it "wraps the label, control and hint" do
      doc = html(build_form { |form| form.field :email, "Email", hint: "We never share it." })

      field = doc.at(".UnmagicField")
      expect(field["data-field"]).to eq("")
      expect(field.at("label.UnmagicLabel").text).to eq("Email")
      expect(field.at("input[type=text]")["name"]).to eq("signup[email]")
      expect(field.at("p.UnmagicHint").text).to eq("We never share it.")
    end

    it "marks a required field on the label and the control" do
      doc = html(build_form { |form| form.field :email, "Email", required: true })

      expect(doc.at(".UnmagicLabel__required").text).to eq("*")
      expect(doc.at(".UnmagicField input")["required"]).to eq("required")
    end

    it "builds the control named by as:" do
      doc = html(build_form { |form| form.field :email, "Email", as: :email_field })

      expect(doc.at(".UnmagicField input")["type"]).to eq("email")
    end

    it "takes a control from a block, and then leaves it alone" do
      signup = Signup.new
      signup.validate

      doc = html(build_form(signup) { |form| form.field(:email, "Email") { form.text_area :email } })

      expect(doc.at("textarea")).not_to be_nil
      # The message is still marked; only the control is the caller's business.
      expect(doc.at(".UnmagicError")).not_to be_nil
      expect(doc.at("textarea")["aria-invalid"]).to be_nil
    end

    it "flags an invalid field and prints its errors as a sentence" do
      signup = Signup.new
      signup.validate

      doc = html(build_form(signup) { |form| form.field :email, "Email" })

      expect(doc.at(".UnmagicField input")["aria-invalid"]).to eq("true")
      expect(doc.at("p.UnmagicError").text).to eq("can't be blank")
    end

    it "says nothing about errors when there are none" do
      doc = html(build_form { |form| form.field :email, "Email" })

      expect(doc.at(".UnmagicError")).to be_nil
      expect(doc.at(".UnmagicField input")["aria-invalid"]).to be_nil
    end
  end

  describe "#group" do
    it "lays its fields out in a row, and they stop carrying their own margin" do
      doc = html(build_form do |form|
        form.group do
          form.field(:name, "Name") + form.field(:email, "Email")
        end
      end)

      expect(doc.at(".UnmagicFieldGroup")).not_to be_nil
      expect(doc.css(".UnmagicField--in-row").size).to eq(2)
    end

    it "renders compact when inline" do
      doc = html(build_form { |form| form.group(inline: true) { form.field(:name, "Name") } })

      expect(doc.at(".UnmagicFieldGroup--inline")).not_to be_nil
      expect(doc.at(".UnmagicField--inline")).not_to be_nil
    end

    it "does not leak the row layout to fields after it" do
      doc = html(build_form do |form|
        form.group { form.field(:name, "Name") } + form.field(:email, "Email")
      end)

      expect(doc.css(".UnmagicField--in-row").size).to eq(1)
    end
  end

  describe "#errors_summary" do
    it "reads the record's whole-object errors" do
      signup = Signup.new
      signup.errors.add(:base, "That address is already signed up")

      doc = html(build_form(signup, &:errors_summary))

      expect(doc.at(".UnmagicFormErrors")["role"]).to eq("alert")
      expect(doc.at(".UnmagicFormErrors").text).to eq("That address is already signed up")
    end

    it "renders nothing when the record is clean" do
      expect(build_form(&:errors_summary).to_s).not_to include("UnmagicFormErrors")
    end
  end

  describe "#check_box_field" do
    it "puts the label beside the box and the hint under it" do
      doc = html(build_form { |form| form.check_box_field :terms, "Accept terms", hint: "You can opt out later." })

      expect(doc.at("label.UnmagicCheckField input[type=checkbox]")).not_to be_nil
      expect(doc.at(".UnmagicCheckField__label").text).to eq("Accept terms")
      expect(doc.at(".UnmagicHint").text).to eq("You can opt out later.")
    end
  end

  describe "#submit" do
    it "conjugates the label for the length of the submit" do
      doc = html(build_form { |form| form.submit "Add label" })

      button = doc.at("button[type=submit]")
      expect(button.text).to eq("Add label")
      expect(button["data-turbo-submits-with"]).to eq("Adding label…")
    end

    it "handles the verbs the plain rule gets wrong" do
      expect(html(build_form { |form| form.submit "Run import" }).at("button")["data-turbo-submits-with"])
        .to eq("Running import…")
      expect(html(build_form { |form| form.submit "Save" }).at("button")["data-turbo-submits-with"])
        .to eq("Saving…")
    end

    it "takes an explicit label, or none at all" do
      expect(html(build_form { |form| form.submit "Go", submitting: "Off we go…" })
        .at("button")["data-turbo-submits-with"]).to eq("Off we go…")
      expect(html(build_form { |form| form.submit "Go", submitting: false })
        .at("button")["data-turbo-submits-with"]).to be_nil
    end

    it "takes its content from a block, keeping the label for the submitting text" do
      doc = html(build_form { |form| form.submit("Add label") { "PLUS Add label" } })

      expect(doc.at("button").text).to eq("PLUS Add label")
      expect(doc.at("button")["data-turbo-submits-with"]).to eq("Adding label…")
    end

    it "defaults to Save" do
      expect(html(build_form(&:submit)).at("button").text).to eq("Save")
    end

    it "takes its classes from the configured seam" do
      Unmagic::Components.configure do |config|
        config.submit_class = ->(_view, variant) { "btn btn-#{variant}" }
      end

      doc = html(build_form { |form| form.submit "Save", variant: :danger })

      expect(doc.at("button")["class"]).to eq("btn btn-danger")
    end
  end

  describe "#form_value_for" do
    it "reads a model attribute" do
      expect(build_form_builder(Signup.new(email: "ada@example.com")).form_value_for(:email))
        .to eq("ada@example.com")
    end

    it "reads a hash-ish object by string or symbol" do
      expect(build_form_builder({ "email" => "grace@example.com" }).form_value_for(:email))
        .to eq("grace@example.com")
    end
  end
end
