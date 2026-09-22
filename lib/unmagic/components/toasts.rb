# frozen_string_literal: true

module Unmagic
  module Components
    # Permanent regions for flash and streamed toast templates.
    class Toasts
      def initialize(view, flashes, duration:, id: Toast::TARGET, position: :top_end, scoped: false, **options)
        Toast.validate(:position, position, Toast::POSITIONS)
        Toast.validate_duration(duration)
        @view, @flashes, @duration, @id, @position, @scoped, @options = view, flashes, duration, id, position, scoped, options
      end

      def render
        view.content_tag("unmagic-toasts", **@options, id: @id, duration: @duration,
          position: @position, scoped: (@scoped ? "" : nil)) do
          safe_join [ *stacks, *blueprints, *templates ]
        end
      end

      private

      attr_reader :view
      delegate :tag, :safe_join, to: :view, private: true

      def stacks
        # Keep the original top-end stack id for compatibility with cached pages.
        ([ :top_end ] + (Toast::POSITIONS - [ :top_end ])).map do |position|
          suffix = position == :top_end ? "stack" : "stack_#{position}"
          tag.div(class: "UnmagicToasts__stack", id: "#{@id}_#{suffix}",
            popover: (@scoped ? nil : "manual"), "aria-live": "polite",
            data: { turbo_permanent: "", position: position })
        end
      end

      # JavaScript clones the same Ruby-rendered structure as streamed toasts.
      # These templates are deliberately distinct from incoming toast templates.
      def blueprints
        prototype = Toast.new(view, "", title: "")
        prototype.actions { tag.button("", type: "button", class: Button.classes(size: :small)) }
        [
          tag.template(prototype.render, data: { unmagic_toast_blueprint: "" }),
          *Toast::TONES.map do |tone|
            tag.template(Icons.svg(view, Icons::TONE_ICONS.fetch(tone, :info), class: "UnmagicToast__icon"),
              data: { unmagic_toast_icon: tone })
          end
        ]
      end

      def templates
        tones = Components.configuration.flash_tones
        @flashes.each_with_object([]) do |(type, messages), templates|
          tone = tones.fetch(type.to_s, :info)
          Array(messages).each do |message|
            templates << Toast.new(view, message, tone: tone).template if message.present?
          end
        end
      end
    end
  end
end
