# frozen_string_literal: true

RSpec.describe "switches, radios, sliders, passwords, codes, input groups and toggles" do
  let(:view) { build_view }
  let(:form) { build_form_builder(Signup.new(terms: true), view: view) }

  describe "FormBuilder#switch_field" do
    it "is a checkbox with role switch, labelled beside it" do
      doc = html(form.switch_field(:terms, "Agree", hint: "You must."))

      label = doc.at("label.UnmagicCheckField.UnmagicCheckField--switch.UnmagicCheckField--hinted")
      input = label.at("input[type=checkbox].UnmagicSwitch")
      expect([ input["role"], input.key?("checked") ]).to eq([ "switch", true ])
      expect(label.at(".UnmagicCheckField__label").text).to eq("Agree")
      expect(label.at(".UnmagicHint").text).to eq("You must.")
    end

    it "works as a field's control and as a tag" do
      expect(html(form.field(:terms, "Agree", as: :switch)).at(".UnmagicField input.UnmagicSwitch")["role"]).to eq("switch")

      tag = html(view.switch_tag("notify", checked: true, label: "Notify")).at("label")
      expect(tag.at("input.UnmagicSwitch")["name"]).to eq("notify")
      expect(tag.at(".UnmagicCheckField__label").text).to eq("Notify")
    end
  end

  describe "FormBuilder#radio_button_collection" do
    let(:plans) { [ Struct.new(:id, :name, :summary).new(1, "Starter", "One person"), Struct.new(:id, :name, :summary).new(2, "Team", "Everybody") ] }

    it "renders a fieldset of card radios with hints, required and legend" do
      doc = html(form.radio_button_collection(:name, plans, :id, :name, legend: "Plan", hint_method: :summary, variant: :cards, inline: true, required: true))

      fieldset = doc.at("fieldset.UnmagicChoiceGroup")
      expect(fieldset.at("legend.UnmagicLabel").text).to eq("Plan *")
      list = fieldset.at(".UnmagicCheckList.UnmagicCheckList--cards.UnmagicCheckList--cards-inline")
      cards = list.css("label.UnmagicCheckField--card")
      expect(cards.size).to eq(2)
      expect(cards[0].at("input[type=radio].UnmagicRadio").key?("required")).to be(true)
      expect(cards.map { |c| c.at(".UnmagicHint").text }).to eq([ "One person", "Everybody" ])
    end

    it "is a radiogroup div without a legend, and rejects an unknown variant" do
      doc = html(form.radio_button_collection(:name, plans, :id, :name, "aria-label": "Plan"))
      expect(doc.at("div.UnmagicChoiceGroup[role=radiogroup]")["aria-label"]).to eq("Plan")
      expect(doc.at(".UnmagicCheckList--cards")).to be_nil
      expect { form.radio_button_collection(:name, plans, :id, :name, variant: :tiles) }.to raise_error(ArgumentError, /unknown radio_button_collection variant/)
    end

    it "renders a single labelled radio" do
      label = html(form.radio_button_field(:name, "daily", "Daily", hint: "Each morning")).at("label.UnmagicCheckField")
      expect(label.at("input[type=radio][value=daily].UnmagicRadio")).to be_present
      expect(label.at(".UnmagicHint").text).to eq("Each morning")
    end
  end

  describe "FormBuilder#range_field and #password_field" do
    it "styles a slider" do
      expect(html(form.range_field(:name, min: 0, max: 10)).at("input[type=range]")["class"]).to eq("UnmagicRange")
    end

    it "wraps a password in a reveal element only when asked" do
      plain = html(form.password_field(:name)).at("input")
      expect([ plain["type"], plain["class"] ]).to eq(%w[password UnmagicInput])

      doc = html(form.password_field(:name, reveal: true, autocomplete: "new-password"))
      wrapper = doc.at("unmagic-password.UnmagicPassword")
      expect(wrapper.at("input")["autocomplete"]).to eq("new-password")
      button = wrapper.at("button.UnmagicPassword__toggle")
      expect([ button["aria-controls"], button["aria-pressed"], button["aria-label"], button.key?("hidden") ]).to eq([ "signup_name", "false", "Show password", true ])
      expect(button.css("svg").map { |s| s["class"][/UnmagicPassword__\w+/] }).to eq(%w[UnmagicPassword__show UnmagicPassword__hide])

      expect(html(view.password_field_tag("pw", nil, reveal: true)).at("unmagic-password button")["aria-controls"]).to eq("pw")
    end
  end

  describe "FormBuilder#one_time_code_field" do
    it "is one input with the code attributes inside its element" do
      doc = html(form.one_time_code_field(:name, length: 6, submit: true))

      element = doc.at("unmagic-one-time-code.UnmagicOneTimeCode")
      expect([ element["length"], element["charset"], element.key?("submit") ]).to eq([ "6", "numeric", true ])
      input = element.at("input.UnmagicOneTimeCode__input.UnmagicInput")
      expect([ input["inputmode"], input["pattern"], input["maxlength"], input["autocomplete"], input["value"] ]).to eq([ "numeric", "[0-9]{6}", "6", "one-time-code", nil ])

      alnum = html(view.one_time_code_field_tag("code", length: 8, charset: :alphanumeric)).at("input")
      expect([ alnum["pattern"], alnum["inputmode"] ]).to eq([ "[A-Za-z0-9]{8}", "text" ])
      expect { form.one_time_code_field(:name, length: 2) }.to raise_error(ArgumentError, /4 to 10/)
      expect { form.one_time_code_field(:name, charset: :emoji) }.to raise_error(ArgumentError, /unknown one_time_code charset/)
    end
  end

  describe "#input_group" do
    it "joins text addons and markup addons to the control" do
      doc = html(view.input_group(prefix: "https://", suffix: view.tag.button("Go")) { view.tag.input(class: "UnmagicInput") })

      group = doc.at("div.UnmagicInputGroup")
      expect(group.children.map(&:name)).to eq(%w[span input span])
      expect(group.children.first["class"]).to eq("UnmagicInputGroup__addon UnmagicInputGroup__addon--text")
      expect(group.children.last["class"]).to eq("UnmagicInputGroup__addon")
      expect(group.children.last.at("button").text).to eq("Go")
    end
  end

  describe "#toggle and #toggle_group" do
    it "is a pressed button, or a checkbox drawn as one with a name" do
      button = html(view.toggle("Bold", pressed: true, icon: :pencil, size: :small)).at("button.UnmagicToggle")
      expect([ button["aria-pressed"], button["type"], button["class"] ]).to eq([ "true", "button", "UnmagicToggle UnmagicToggle--small" ])
      expect(button.at("svg.UnmagicToggle__icon")).to be_present
      expect(button.at(".UnmagicToggle__label").text).to eq("Bold")

      label = html(view.toggle("Archived", name: "archived", pressed: true)).at("label.UnmagicToggle.UnmagicToggle--input")
      input = label.at("input.UnmagicToggle__input")
      expect([ input["type"], input["name"], input.key?("checked") ]).to eq([ "checkbox", "archived", true ])
      expect(label.at(".UnmagicToggle__face .UnmagicToggle__label").text).to eq("Archived")
    end

    it "renders a radiogroup of joined choices with the value checked, or checkboxes with multiple:" do
      doc = html(view.toggle_group(name: "range", value: "7d", label: "Range") do |group|
        group.option "24 hours", "24h"
        group.option "7 days", "7d", icon: :clock
        group.option "30 days", "30d", disabled: true
      end)

      group = doc.at("div.UnmagicToggleGroup[role=radiogroup]")
      expect(group["aria-label"]).to eq("Range")
      inputs = group.css("label.UnmagicToggle > input.UnmagicToggle__input")
      expect(inputs.map { |i| [ i["type"], i["name"], i["value"], i.key?("checked"), i.key?("disabled") ] }).to eq([
        [ "radio", "range", "24h", false, false ], [ "radio", "range", "7d", true, false ], [ "radio", "range", "30d", false, true ]
      ])
      expect(group.css("label")[1].at("svg.UnmagicToggle__icon")).to be_present

      multi = html(view.toggle_group(name: "days", value: %w[mon wed], multiple: true) { |g| g.option "Mon", "mon"; g.option "Tue", "tue" })
      expect(multi.at("div")["role"]).to eq("group")
      expect(multi.css("input").map { |i| [ i["type"], i["name"], i.key?("checked") ] }).to eq([ [ "checkbox", "days[]", true ], [ "checkbox", "days[]", false ] ])
      expect(view.toggle_group(name: "x") { |_g| }).to be_blank
    end
  end
end
