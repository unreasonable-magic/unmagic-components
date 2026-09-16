# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # An agent asking to be allowed something, with the answer under the
      # reasoning rather than in a dialog that arrived without it. See
      # ActionViewHelpers#ai_chat_permission.
      class Permission
        STATES = %i[waiting granted refused lapsed].freeze

        OUTCOMES = { granted: "Allowed.", refused: "Refused.",
                     lapsed: "Answered in the chat — nothing was granted." }.freeze

        def initialize(view, tool:, state:, url: nil, live: false, outcome: nil, **options)
          AIChat.validate!("ai_chat_permission", :state, state, STATES)
          raise ArgumentError, "a waiting ai_chat_permission needs a url: to answer to" if state == :waiting && url.blank?

          @view = view
          @tool = tool
          @state = state
          @url = url
          @live = live
          @outcome = outcome
          @options = options
          @arguments = []
          @summary = nil
          @reason = nil
          @examples = []
          @actions = []
        end

        # A name and value the grant is for, beside the tool in the ask line.
        def argument(name, value)
          @arguments << [ name, value ]
          nil
        end

        def summary(content = nil, &block)
          @summary = block ? view.capture(&block) : content
          nil
        end

        def reason(content = nil, &block)
          @reason = block ? view.capture(&block) : content
          nil
        end

        def example(text)
          @examples << text
          nil
        end

        # Repeatable: the second is the wider grant, offered only when there is
        # something left to widen. The host decides that; the gem can't know.
        def allow(label = nil, params: {}, confirm: nil, method: :post)
          @actions << [ :allow, label || AIChat.t("permission.allow", default: "Allow"), params, confirm, method ]
          nil
        end

        def refuse(label = nil, params: {}, confirm: nil, method: :delete)
          @actions << [ :refuse, label || AIChat.t("permission.refuse", default: "Refuse"), params, confirm, method ]
          nil
        end

        def render
          waiting = @state == :waiting

          # Focus lands on the card, never on Allow, so a stray Enter grants nothing.
          view.content_tag(:div, **@options,
            role: ("alert" if @live && waiting),
            tabindex: ("-1" if waiting),
            class: view.class_names("UnmagicAIChatPermission", "UnmagicAIChatPermission--#{@state}", @options[:class])) do
            safe_join [
              head(waiting),
              ask,
              (tag.div(@summary, class: "UnmagicAIChatPermission__summary UnmagicProse") if @summary.present?),
              (tag.div(@reason, class: "UnmagicAIChatPermission__reason UnmagicProse") if @reason.present?),
              examples,
              waiting ? actions : outcome
            ].compact
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def head(waiting)
          tag.div(class: "UnmagicAIChatPermission__head") do
            safe_join [
              Icons.svg(view, :shield_alert),
              waiting ? AIChat.t("permission.waiting", default: "Wants permission") : AIChat.t("permission.asked", default: "Wanted permission")
            ]
          end
        end

        # The tool's own name, untranslated: it is what will be called and what the
        # permission is written down against.
        def ask
          tag.p(class: "UnmagicAIChatPermission__ask") do
            safe_join [
              tag.code(@tool, class: "UnmagicAIChatPermission__tool"),
              *@arguments.map { |name, value| tag.span("#{name}: #{value}", class: "UnmagicAIChatPermission__argument") }
            ], " "
          end
        end

        def examples
          return if @examples.empty?

          tag.ul(safe_join(@examples.map { |text| tag.li(text) }), class: "UnmagicAIChatPermission__examples")
        end

        def actions
          allows = 0

          tag.div(class: "UnmagicAIChatPermission__actions") do
            safe_join(@actions.map do |kind, label, params, confirm, method|
              modifier =
                if kind == :refuse then nil
                elsif (allows += 1) == 1 then "UnmagicAIChatPermission__allow"
                else "UnmagicAIChatPermission__widen"
                end

              # The block form, so it's a <button> whatever the host's Rails defaults.
              view.button_to(@url, method: method, params: params,
                form: { data: { turbo_confirm: confirm }.compact },
                class: view.class_names(Button.classes, modifier)) { label }
            end)
          end
        end

        def outcome
          text = @outcome || AIChat.t("permission.#{@state}", default: OUTCOMES.fetch(@state))
          tag.p(text, class: "UnmagicAIChatPermission__outcome")
        end
      end
    end
  end
end
