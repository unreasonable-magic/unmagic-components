# frozen_string_literal: true

RSpec.describe "dialogs" do
  let(:view) { build_view }

  describe "#dialog" do
    it "renders the panel chrome with a titled header, body and footer" do
      doc = html(view.dialog(title: "Edit label") do |dialog|
        dialog.footer { view.tag.button("Save") }
        "Body"
      end)

      title = doc.at(".UnmagicDialog__title")
      expect(title.text).to eq("Edit label")
      expect(title["id"]).to match(/\Aunmagic_dialog_\h{8}_title\z/)
      expect(doc.at(".UnmagicDialog__close")["data-unmagic-dialog-close"]).to eq("")
      expect(doc.at(".UnmagicDialog__close")["aria-label"]).to eq("Close")
      expect(doc.at(".UnmagicDialog__body").text).to eq("Body")
      expect(doc.at(".UnmagicDialog__footer button").text).to eq("Save")
    end

    it "omits the footer when none is declared, and the title when none is given" do
      doc = html(view.dialog { "Body" })

      expect(doc.at(".UnmagicDialog__footer")).to be_nil
      expect(doc.at(".UnmagicDialog__title")).to be_nil
      expect(doc.at(".UnmagicDialog__close")).not_to be_nil
    end

    it "drops the header entirely with no title and close: false" do
      doc = html(view.dialog(close: false) { "Body" })

      expect(doc.at(".UnmagicDialog__header")).to be_nil
    end

    it "wraps itself in the modal frame on a request aimed at it" do
      framed = html(build_view(turbo_frame: "modal").dialog(title: "Edit") { "Body" })
      plain = html(view.dialog(title: "Edit") { "Body" })

      expect(framed.at("turbo-frame#modal > .UnmagicDialog")).not_to be_nil
      expect(plain.at("turbo-frame")).to be_nil
    end

    it "follows a configured frame id" do
      Unmagic::Components.configure { |config| config.modal_frame_id = "sheet" }

      doc = html(build_view(turbo_frame: "sheet").dialog { "Body" })

      expect(doc.at("turbo-frame#sheet > .UnmagicDialog")).not_to be_nil
    end

    it "builds a form around the whole panel, so the footer's submit is inside it" do
      form_options = { model: Signup.new, url: "/signups", builder: Unmagic::Components::FormBuilder }
      markup = build_view(turbo_frame: "modal").dialog(title: "Sign up", form: form_options) do |dialog, form|
        dialog.footer { form.submit("Save") }
        form.text_field(:email)
      end

      doc = html(markup)
      expect(doc.at("turbo-frame#modal > form > .UnmagicDialog")).not_to be_nil
      expect(doc.at("form .UnmagicDialog__footer button[type=submit]").text).to eq("Save")
      expect(doc.at("form .UnmagicDialog__body input[name='signup[email]']")).not_to be_nil
    end

    it "widens with size: :wide, adds class:, and rejects an unknown size" do
      doc = html(view.dialog(size: :wide, class: "mt-4") { "Body" })

      expect(doc.at(".UnmagicDialog")["class"]).to eq("UnmagicDialog UnmagicDialog--wide mt-4")
      expect { view.dialog(size: :huge) { "Body" } }.to raise_error(ArgumentError, /unknown dialog size :huge/)
    end
  end

  describe "#modal_frame" do
    it "mounts a dialog around the frame, with skeleton and error templates" do
      doc = html(view.modal_frame)

      dialog = doc.at("unmagic-modal > dialog.UnmagicDialogBox")
      expect(dialog["data-unmagic-dialog"]).to eq("")
      expect(dialog.at("> turbo-frame#modal")).not_to be_nil
      expect(dialog.at("> template[data-unmagic-modal-skeleton]")).not_to be_nil
      expect(dialog.at("> template[data-unmagic-modal-error]")).not_to be_nil
    end

    it "gives the error state a retry button and the skeleton a status role" do
      markup = view.modal_frame.to_s
      skeleton = Nokogiri::HTML5.fragment(markup[%r{<template data-unmagic-modal-skeleton="">(.*?)</template>}m, 1])
      error = Nokogiri::HTML5.fragment(markup[%r{<template data-unmagic-modal-error="">(.*?)</template>}m, 1])

      expect(skeleton.at(".UnmagicDialog")["role"]).to eq("status")
      expect(skeleton.css(".UnmagicSkeleton").size).to eq(8)
      expect(error.at(".UnmagicDialog")["role"]).to eq("alert")
      expect(error.at("[data-unmagic-modal-retry]").text).to eq("Try again")
    end

    it "takes an id" do
      expect(html(view.modal_frame(id: "sheet")).at("turbo-frame#sheet")).not_to be_nil
    end
  end

  describe "#modal_link_to" do
    it "aims a link at the modal frame, keeping its other data" do
      link = html(view.modal_link_to("Edit", "/labels/1/edit", class: "btn", data: { foo: "bar" })).at("a")

      expect(link["href"]).to eq("/labels/1/edit")
      expect(link["class"]).to eq("btn")
      expect(link["data-turbo-frame"]).to eq("modal")
      expect(link["data-foo"]).to eq("bar")
    end

    it "takes a block" do
      link = html(view.modal_link_to("/labels/new") { "New" }).at("a")

      expect(link.text).to eq("New")
      expect(link["href"]).to eq("/labels/new")
      expect(link["data-turbo-frame"]).to eq("modal")
    end
  end

  describe "#dialog_tag and #dialog_button" do
    it "renders a labelled dialog with the panel inside" do
      doc = html(view.dialog_tag("help", title: "Scopes", class: "extra") { "Scopes limit a token." })

      dialog = doc.at("dialog#help")
      expect(dialog["class"]).to eq("UnmagicDialogBox extra")
      expect(dialog["data-unmagic-dialog"]).to eq("")
      expect(dialog["aria-labelledby"]).to eq(dialog.at(".UnmagicDialog__title")["id"])
      expect(dialog.at(".UnmagicDialog__body").text).to eq("Scopes limit a token.")
    end

    it "leaves an untitled dialog unlabelled" do
      expect(html(view.dialog_tag("help") { "Body" }).at("dialog")["aria-labelledby"]).to be_nil
    end

    it "opens a dialog by id" do
      button = html(view.dialog_button("What's this?", dialog: "help", class: "link")).at("button")

      expect(button.text).to eq("What's this?")
      expect(button["type"]).to eq("button")
      expect(button["class"]).to eq("link")
      expect(button["data-unmagic-dialog-open"]).to eq("help")
      expect(button["aria-controls"]).to eq("help")
      expect(button["aria-haspopup"]).to eq("dialog")
    end
  end

  describe "#confirm_dialog_template" do
    it "renders the confirm dialog's markup, with translatable words" do
      I18n.backend.store_translations(:en, unmagic: { components: { confirm: { accept: "Yes" } } })

      markup = view.confirm_dialog_template.to_s
      doc = Nokogiri::HTML5.fragment(markup[%r{<template data-unmagic-confirm="">(.*)</template>}m, 1])

      expect(doc.at("dialog")["role"]).to eq("alertdialog")
      expect(doc.at("form[method=dialog]")).not_to be_nil
      expect(doc.at("[data-unmagic-confirm-title]").text).to eq("Are you sure?")
      expect(doc.at("[data-unmagic-confirm-accept]")["value"]).to eq("confirm")
      expect(doc.at("[data-unmagic-confirm-accept]").text).to eq("Yes")
      expect(doc.at("[data-unmagic-confirm-cancel]").text).to eq("Cancel")
    ensure
      I18n.reload!
    end
  end

  describe "#button_classes" do
    it "builds the class string for a variant and size" do
      expect(view.button_classes).to eq("UnmagicButton")
      expect(view.button_classes(:primary, size: :small)).to eq("UnmagicButton UnmagicButton--primary UnmagicButton--small")
      expect { view.button_classes(:loud) }.to raise_error(ArgumentError, /unknown button variant :loud/)
    end
  end
end
