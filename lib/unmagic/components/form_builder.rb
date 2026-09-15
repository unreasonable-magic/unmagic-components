# frozen_string_literal: true

require "action_view"
require "action_view/helpers"

module Unmagic
  module Components
    # The chrome around a form control: the wrapper, the label and its required
    # marker, the hint, and the error line — the part every app writes the same way
    # and then repeats in every view.
    #
    #   <%= form_with model: @label, builder: Unmagic::Components::FormBuilder do |form| %>
    #     <%= form.errors_summary %>
    #     <%= form.field :name, "Name", required: true, hint: "Shown in the sidebar." %>
    #     <%= form.submit "Add label" %>
    #   <% end %>
    #
    # What the control itself looks like is deliberately not decided here. Apps
    # style inputs in incompatible ways — a class on every input, or a bare-element
    # rule — and a component library that picked one would be wrong in the other. So
    # the builder emits structure and leaves the control's own appearance alone.
    class FormBuilder < ::ActionView::Helpers::FormBuilder
      # Verbs the plain "drop a trailing -e, add -ing" rule gets wrong (consonant
      # doubling). Everything else the rule handles: Save -> Saving, Create ->
      # Creating, Add -> Adding, Continue -> Continuing.
      SUBMIT_GERUNDS = {
        "submit" => "Submitting",
        "set" => "Setting",
        "get" => "Getting",
        "log" => "Logging",
        "run" => "Running"
      }.freeze

      # Label + control + hint + error, wrapped consistently. Pass a block to supply
      # a control the builder doesn't know how to make (a select, a file picker, two
      # inputs side by side); otherwise it is built from `as:`.
      #
      #   <%= form.field :email, "Email", required: true, as: :email_field %>
      #   <%= form.field :role, "Role" do %>
      #     <%= form.select :role, Role.all %>
      #   <% end %>
      def field(method, label_text = nil, required: false, hint: nil, as: :text_field, **options, &block)
        options = options.merge(required: true) if required && !block

        errors = errors_for(method)
        options = options.merge("aria-invalid" => "true") if errors.any? && !block

        control = block ? @template.capture(&block) : public_send(as, method, options)

        @template.content_tag(:div, class: field_classes, data: { field: "" }) do
          @template.safe_join [
            (field_label(method, label_text, required) if label_text),
            control,
            (@template.content_tag(:p, hint, class: "UnmagicHint") if hint),
            (@template.content_tag(:p, errors.to_sentence, class: "UnmagicError") if errors.any?)
          ].compact
        end
      end

      def label(method, text = nil, options = {}, &block)
        options = options.dup
        options[:class] = @template.class_names("UnmagicLabel", options[:class])
        super
      end

      # Lay the contained fields out in a row — a first-name / last-name pair above
      # other stacked fields. With inline: true they render compact and auto-width,
      # for a filter toolbar. Groups can't nest.
      def group(inline: false, **options, &block)
        @group = inline ? :inline : :row
        content = @template.capture(&block)
        @group = nil

        classes = @template.class_names(inline ? "UnmagicFieldGroup--inline" : "UnmagicFieldGroup", options[:class])
        @template.content_tag(:div, content, class: classes)
      end

      # The record's whole-object errors, read as a sentence. Attribute errors show
      # under their own field; these have nowhere else to go.
      def errors_summary
        errors = errors_for(:base)
        return if errors.none?

        @template.content_tag(:div, errors.to_sentence, class: "UnmagicFormErrors", role: "alert")
      end

      # A checkbox with its label beside it, and an optional hint under that.
      def check_box_field(method, label_text, hint: nil, **options)
        @template.content_tag(:label, class: "UnmagicCheckField") do
          text = [ @template.content_tag(:span, label_text, class: "UnmagicCheckField__label") ]
          text << @template.content_tag(:span, hint, class: "UnmagicHint") if hint

          @template.safe_join [
            check_box(method, options),
            @template.content_tag(:span, @template.safe_join(text), class: "UnmagicCheckField__text")
          ]
        end
      end

      # A vertical list of checkboxes from a collection — Rails' collection_check_boxes
      # with the labelling and spacing baked in. inline: true flows them in a row.
      def check_box_collection(method, collection, value_method, text_method, inline: false, **options)
        body = collection_check_boxes(method, collection, value_method, text_method) do |check_box|
          @template.content_tag(:label, class: "UnmagicCheckField") do
            @template.safe_join [
              check_box.check_box(options),
              @template.content_tag(:span, check_box.text, class: "UnmagicCheckField__label")
            ]
          end
        end

        @template.content_tag(:div, body, class: inline ? "UnmagicCheckList--inline" : "UnmagicCheckList")
      end

      # A submit button that says what it is doing while it does it: Turbo swaps the
      # label for the conjugated verb ("Save" -> "Saving…") for the length of the
      # submit. Pass submitting: false to leave the label alone, or a string to
      # choose it.
      def submit(value = nil, options = {}, &block)
        options = options.dup
        variant = options.delete(:variant) || :primary
        submitting = options.delete(:submitting)
        value ||= "Save"

        options[:type] = "submit"
        options[:class] = @template.class_names(
          Components.configuration.submit_class.call(@template, variant), options[:class]
        )
        options[:data] = with_submitting_text(options[:data], value, submitting)

        # A block is the caller's own button content — an icon beside the label —
        # while `value` stays the label the submitting text is conjugated from.
        @template.content_tag(:button, options) { block ? @template.capture(&block) : value }
      end

      # A textarea that grows with what's typed, from its rows up to its CSS
      # max-height, then scrolls. Works as a field's control too:
      #
      #   <%= form.field :body, "Message", as: :autogrow_text_area, rows: 2 %>
      #
      # Needs import "unmagic/components/autogrow".
      def autogrow_text_area(method, options = {})
        Components::Autogrow.wrap(@template, text_area(method, options))
      end

      # A hidden field holding a fresh, time-ordered UUIDv7, so the form submits an
      # id the client already knows: to match an optimistically rendered element to
      # the record the server creates under the same id.
      #
      #   <%= form.uuid_field :id %>
      #
      # A new id is minted when the element upgrades and every time the form is
      # reset, so a form that clears itself after each submit sends a fresh one.
      # Without the script the server's own id is sent. Needs import
      # "unmagic/components/uuid_input".
      def uuid_field(method, options = {})
        Components::UuidInput.new(@template, field_name(method), **options).render
      end

      # The value to show for a field, whether the object is a model or something
      # hash-ish (a JSON Schema instance, a params object). Reads what the user
      # actually typed when the object tracks that, so a rejected cast still shows
      # their input rather than nil.
      def form_value_for(method)
        if hash_value_object?
          @object.key?(method.to_s) ? @object[method.to_s] : @object[method.to_sym]
        elsif @object.respond_to?("#{method}_before_type_cast") && form_value_came_from_user?(method)
          @object.public_send("#{method}_before_type_cast")
        elsif @object.respond_to?(method)
          @object.public_send(method)
        end
      end

      private

      def field_classes
        case @group
        when :row then "UnmagicField UnmagicField--in-row"
        when :inline then "UnmagicField UnmagicField--inline"
        else "UnmagicField"
        end
      end

      def field_label(method, text, required)
        return label(method, text) unless required

        label(method) do
          @template.safe_join [ text, " ", @template.content_tag(:span, "*", class: "UnmagicLabel__required") ]
        end
      end

      def errors_for(method)
        return [] unless @object.respond_to?(:errors)

        @object.errors[method]
      end

      def hash_value_object?
        @object.respond_to?(:key?) && @object.respond_to?(:[]) && @object.respond_to?(:to_h)
      end

      def form_value_came_from_user?(method)
        came_from_user = "#{method}_came_from_user?"
        !@object.respond_to?(came_from_user) || @object.public_send(came_from_user)
      end

      # data-turbo-submits-with, unless the caller opted out or set their own.
      def with_submitting_text(data, value, submitting)
        return data if submitting == false

        text = submitting.is_a?(String) ? submitting : submitting_text(value)
        return data unless text

        data = (data || {}).dup
        data[:turbo_submits_with] = text unless data.key?(:turbo_submits_with)
        data
      end

      # "Save" -> "Saving…", "Add label" -> "Adding label…".
      def submitting_text(value)
        verb, *rest = value.to_s.split
        return unless verb

        gerund = SUBMIT_GERUNDS[verb.downcase] || "#{verb.sub(/e\z/i, "")}ing"
        "#{[ gerund, *rest ].join(" ")}…"
      end
    end
  end
end
