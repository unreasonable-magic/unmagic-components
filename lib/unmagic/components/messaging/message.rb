# frozen_string_literal: true

require "active_support/core_ext/string/filters"

module Unmagic
  module Components
    module Messaging
      # One message in a conversation: who sent it, when, what it says, what came
      # with it and what happened to it. Three looks, one markup. See
      # ActionViewHelpers#message, and AIChat::Message for the agent's turn built
      # on it.
      class Message
        VARIANTS = %i[bubble row email].freeze
        STATUSES = %i[sending sent delivered read failed].freeze
        STATUS_ICONS = { sending: :clock, sent: :check, delivered: :check_check, read: :check_check, failed: :circle_x }.freeze
        STATUS_WORDS = { sending: "Sending", sent: "Sent", delivered: "Delivered", read: "Read", failed: "Not delivered" }.freeze

        # A bubble's avatar is small beside a short line; a row's or an email's is
        # the size of a name and a meta line.
        AVATAR_SIZES = { bubble: :small, row: :medium, email: :medium }.freeze

        # How much of a collapsed message's body shows in its summary.
        SNIPPET_LENGTH = 120

        def initialize(view, variant: :bubble, own: false, author: nil, avatar: nil, time: nil, time_format: nil,
                       continued: false, edited: false, collapsible: false, open: true, id: nil, **options)
          Messaging.validate!("message", :variant, variant, VARIANTS)
          if avatar == true && author.blank?
            raise ArgumentError, "avatar: true draws the author's initials, so it needs an author:"
          end

          @view = view
          @variant = variant
          @own = own
          @author = author
          @avatar = avatar
          @time = time
          @time_format = time_format
          @continued = continued
          @edited = edited
          @collapsible = collapsible
          @open = open
          @id = id
          @options = options
          @meta = @quote = @attachments = @reactions = @extra = @actions = @status = nil
        end

        # A line under the author: "to Ben, Chloe", "via SMS", a badge.
        def meta(content = nil, &block)
          @meta = block ? view.capture(&block) : content
          nil
        end

        # The message this one replies to. href: links the author to it.
        def quote(content = nil, author: nil, href: nil, &block)
          @quote = { content: block ? view.capture(&block) : content, author: author, href: href }
          nil
        end

        # A block that takes an argument gets a message_attachments builder; one
        # that doesn't is the markup.
        def attachments(content = nil, **options, &block)
          @attachments = part(content, block) { Attachments.new(view, **options) }
          nil
        end

        # Likewise: { |r| r.reaction … } builds message_reactions.
        def reactions(content = nil, **options, &block)
          @reactions = part(content, block) { Reactions.new(view, **options) }
          nil
        end

        # What happened to an own message, with the moment it did when that matters
        # ("Read 2:14 pm").
        def status(state, at: nil)
          Messaging.validate!("message status", :state, state, STATUSES)
          @status = [ state, at ]
          nil
        end

        # The host's own footer content: a "3 replies" link, a "View thread".
        def footer(content = nil, &block)
          @extra = block ? view.capture(&block) : content
          nil
        end

        # { |bar| bar.action … } builds message_actions for this message's id, with
        # the options given (reveal:); a block without an argument is the markup.
        def actions(content = nil, **options, &block)
          @actions = part(content, block) do
            raise ArgumentError, "message.actions needs the message's id: for the bar to act on" if @id.blank?

            Actions.new(view, for: @id, **options)
          end
          nil
        end

        def render(body)
          body = prepare(body)

          view.content_tag(:article, **@options, **root_attributes(body), class: root_classes) do
            @collapsible ? collapsible(body) : safe_join([ avatar_cell, main(body), actions_cell ].compact)
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        # The hooks a subclass overrides, and nothing else: see AIChat::Message.

        def root_attributes(_body)
          { id: @id, data: (@options[:data] || {}).merge({ status: @status&.first }.compact) }
        end

        def extra_root_classes = nil

        # An own message without a name still says whose it is.
        def speaker_label
          return unless @own && @author.blank?

          tag.span(Messaging.t("you", default: "You"), class: "UnmagicVisuallyHidden")
        end

        def before_body = nil

        # A bubble was typed into a box, so its line breaks are its formatting; a
        # row or an email is the host's rendered prose.
        def body_element(body)
          tag.div(body, class: view.class_names("UnmagicMessage__body", { "UnmagicProse" => prose? }))
        end

        def footer_element
          parts = [ edited_element, status_element, extra_element ].compact
          return if parts.empty?

          tag.div(safe_join(parts), class: "UnmagicMessage__footer")
        end

        def actions_cell
          tag.div(@actions, class: "UnmagicMessage__actions") if @actions.present?
        end

        # The rest of the rendering.

        def root_classes
          view.class_names("UnmagicMessage", "UnmagicMessage--#{@variant}",
            { "UnmagicMessage--own" => @own, "UnmagicMessage--continued" => @continued }, extra_root_classes, @options[:class])
        end

        def prose? = @variant != :bubble

        def prepare(body) = @variant == :bubble ? trimmed(body) : body

        # The bubble keeps the line breaks that were typed, so a block's own leading
        # newline and indentation would show as a blank first line. Trimming the ends
        # can't make markup, so already-escaped content stays safe.
        def trimmed(body)
          return body.to_s.strip unless body.respond_to?(:html_safe?) && body.html_safe?

          body.to_str.strip.html_safe # rubocop:disable Rails/OutputSafety -- escaped content, only whitespace removed
        end

        def part(content, block)
          if block && block.parameters.any?
            builder = yield
            view.capture(builder, &block)
            builder.render
          else
            block ? view.capture(&block) : content
          end
        end

        def main(body, header: true)
          tag.div(class: "UnmagicMessage__main") do
            safe_join [
              (header_element if header), before_body, quote_element, body_element(body),
              attachments_element, reactions_element, footer_element
            ].compact
          end
        end

        # A continued message keeps the avatar's column but draws nothing in it.
        def avatar_cell(tag_name: :div)
          return unless @avatar

          content = @continued ? "" : Messaging.avatar(view, @avatar, author: @author, size: AVATAR_SIZES.fetch(@variant))
          view.content_tag(tag_name, content, class: "UnmagicMessage__avatar")
        end

        def header_element(tag_name: :div)
          parts = [ speaker_label, author_element, meta_element, time_element ].compact
          return if parts.empty?

          view.content_tag(tag_name, safe_join(parts), class: "UnmagicMessage__header")
        end

        def author_element
          tag.span(@author, class: "UnmagicMessage__author") if @author.present?
        end

        def meta_element
          tag.span(@meta, class: "UnmagicMessage__meta") if @meta.present?
        end

        # A moment goes through local_time_tag, so it reads in the viewer's zone; a
        # string ("Yesterday", "Just now") prints as it is.
        def time_element
          case @time
          when nil, "" then nil
          when String then tag.span(@time, class: "UnmagicMessage__time")
          else
            format = @time_format || (@variant == :email ? :medium : :time)
            LocalTime.new(view, @time, format: format, compact: false, class: "UnmagicMessage__time").render
          end
        end

        def quote_element
          return unless @quote

          content, author, href = @quote.values_at(:content, :author, :href)
          tag.blockquote(cite: href, class: "UnmagicMessage__quote") do
            safe_join [
              (quote_author(author, href) if author.present?),
              tag.span(content, class: "UnmagicMessage__quoteText")
            ].compact
          end
        end

        def quote_author(author, href)
          return tag.span(author, class: "UnmagicMessage__quoteAuthor") unless href

          view.link_to(author, href, class: "UnmagicMessage__quoteAuthor")
        end

        def attachments_element
          tag.div(@attachments, class: "UnmagicMessage__attachments") if @attachments.present?
        end

        def reactions_element
          tag.div(@reactions, class: "UnmagicMessage__reactions") if @reactions.present?
        end

        def edited_element
          tag.span(Messaging.t("edited", default: "Edited"), class: "UnmagicMessage__edited") if @edited
        end

        # A word and a glyph, so the state never rests on the colour alone.
        def status_element
          return unless @status

          state, at = @status
          tag.span(class: "UnmagicMessage__status") do
            safe_join [
              Icons.svg(view, STATUS_ICONS.fetch(state)),
              Messaging.t("status.#{state}", default: STATUS_WORDS.fetch(state)),
              (LocalTime.new(view, at, format: :time, compact: false).render if at)
            ].compact, " "
          end
        end

        def extra_element
          tag.span(@extra, class: "UnmagicMessage__extra") if @extra.present?
        end

        # The header is the disclosure's summary, which only takes phrasing content,
        # so the avatar and header are spans there. The snippet is the body's text,
        # hidden from assistive tech so the summary's name doesn't change with the
        # state, and hidden from view once open.
        def collapsible(body)
          tag.details(open: @open) do
            safe_join [
              tag.summary(class: "UnmagicMessage__summary") do
                safe_join [ avatar_cell(tag_name: :span), header_element(tag_name: :span), snippet(body) ].compact
              end,
              main(body, header: false),
              actions_cell
            ].compact
          end
        end

        def snippet(body)
          text = view.strip_tags(body.to_s).squish.truncate(SNIPPET_LENGTH)
          tag.span(text, class: "UnmagicMessage__snippet", "aria-hidden": "true") if text.present?
        end
      end
    end
  end
end
