# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # Commands offered on a slash, rendered with every item and filtered in the
      # browser, so what can be offered is only ever what exists. See
      # ActionViewHelpers#ai_chat_slash_menu.
      class SlashMenu
        Item = Struct.new(:name, :description, :arguments)

        def initialize(view, for: nil, id: nil, trigger: "/", above: false, insert: nil, **options)
          raise ArgumentError, "ai_chat_slash_menu trigger must be one character" unless trigger.to_s.length == 1

          @view = view
          @for = binding.local_variable_get(:for)
          @id = id || AIChat.random_id("slash_menu")
          @trigger = trigger
          @above = above
          @insert = insert
          @options = options
          @items = []
        end

        def item(name, description: nil, arguments: [])
          @items << Item.new(name.to_s, description, Array(arguments))
          nil
        end

        # An agent with no commands has no menu, not an empty one.
        def render
          return "".html_safe if @items.empty?

          label = AIChat.t("slash_menu.label", default: "Commands")

          view.content_tag("unmagic-slash-menu", **@options,
            for: @for, trigger: @trigger, insert: @insert, hidden: true,
            class: view.class_names("UnmagicAIChatSlashMenu", { "UnmagicAIChatSlashMenu--above" => @above }, @options[:class])) do
            tag.ul(id: "#{@id}_listbox", role: "listbox", "aria-label": label, class: "UnmagicAIChatSlashMenu__list") do
              safe_join(@items.each_with_index.map { |item, index| option(item, index) })
            end
          end
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def option(item, index)
          tag.li(id: "#{@id}_#{index}", role: "option", "aria-selected": index.zero?.to_s, data: { name: item.name },
            class: "UnmagicAIChatSlashMenu__item") do
            safe_join [
              tag.span(class: "UnmagicAIChatSlashMenu__name") do
                safe_join [
                  "#{@trigger}#{item.name}",
                  *item.arguments.map { |argument| tag.span("[#{argument}]", class: "UnmagicAIChatSlashMenu__argument") }
                ], " "
              end,
              (tag.span(item.description, class: "UnmagicAIChatSlashMenu__description") if item.description.present?)
            ].compact
          end
        end
      end
    end
  end
end
