# frozen_string_literal: true

module Unmagic
  module Components
    module Messaging
      # The container a conversation's messages sit in: the spacing between
      # them and, when the conversation updates as it's read, the log a screen
      # reader follows. See ActionViewHelpers#message_thread.
      class Thread
        def initialize(view, id: nil, live: false, label: nil, **options)
          @view = view
          @id = id
          @live = live
          @label = label
          @options = options
        end

        # A log is what ARIA calls a chat, and it is only claimed when the
        # conversation is live: an email thread rendered once is plain content, and
        # a plain <div> can't carry a label.
        def render(content)
          live = @live ? { role: "log", "aria-live": "polite", "aria-relevant": "additions", "aria-label": @label } : {}

          view.content_tag(:div, content, **@options, id: @id, **live,
            class: view.class_names("UnmagicMessageThread", @options[:class]))
        end

        private

        attr_reader :view
      end
    end
  end
end
