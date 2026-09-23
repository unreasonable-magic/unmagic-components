# frozen_string_literal: true

module Unmagic
  module Components
    module Messaging
      # A line across a conversation saying when the messages after it were
      # sent, or that they are new. See ActionViewHelpers#message_separator.
      class Separator
        def initialize(view, label = nil, time: nil, unread: false, **options)
          @view = view
          @label = label
          @time = time
          @unread = unread
          @options = options
        end

        # Not role="separator": a separator's children are presentational, and in
        # a log the date is something a reader should hear before the messages it
        # dates.
        def render
          view.content_tag(:div, **@options, "data-unread": ("" if @unread),
            class: view.class_names("UnmagicMessageSeparator", @options[:class])) do
            tag.span(label, class: "UnmagicMessageSeparator__label") if label.present?
          end
        end

        private

        attr_reader :view

        delegate :tag, to: :view, private: true

        def label
          @label_markup ||= if @label.present?
            @label
          elsif @time
            LocalTime.new(view, @time, format: :date, compact: false).render
          elsif @unread
            Messaging.t("separator.unread", default: "New messages")
          end
        end
      end
    end
  end
end
