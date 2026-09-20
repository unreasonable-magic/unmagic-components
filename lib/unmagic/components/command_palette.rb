# frozen_string_literal: true

module Unmagic
  module Components
    # A dialog with a search box over every command in the app, opened with a
    # shortcut. See ActionViewHelpers#command_palette.
    class CommandPalette
      def initialize(view, id: "command_palette", hotkey: "mod+k", src: nil, min_length: 2, placeholder: nil, **options)
        @view = view
        @id = id
        @hotkey = hotkey
        @src = src
        @min_length = min_length
        @placeholder = placeholder || I18n.t("unmagic.components.command_palette.placeholder", default: "Search or jump to…")
        @options = options
        @groups = []
      end

      def group(label, &block)
        group = Group.new(view)
        view.capture(group, &block)
        @groups << [ label, group ]
        nil
      end

      def render
        raise ArgumentError, "command_palette needs groups of commands, or src:" if @groups.empty? && @src.nil?

        combobox_id = "#{@id}_combobox"

        view.content_tag("unmagic-command-palette", **@options, hotkey: (@hotkey.presence || nil),
          class: view.class_names("UnmagicCommandPalette", @options[:class])) do
          tag.dialog(id: @id, class: "UnmagicDialogBox UnmagicCommandPalette__dialog", data: { unmagic_dialog: "" },
            "aria-label": I18n.t("unmagic.components.command_palette.label", default: "Command palette")) do
            view.content_tag("unmagic-combobox", id: combobox_id, class: "UnmagicCombobox UnmagicCombobox--inline", mode: "activate",
              src: @src, "min-length": (@min_length if @src)) do
              safe_join [
                tag.div(class: "UnmagicCommandPalette__search") do
                  safe_join [
                    Icons.svg(view, :search),
                    tag.input(type: "text", class: "UnmagicCombobox__input", role: "combobox", "aria-expanded": "true",
                      "aria-controls": "#{combobox_id}_listbox", "aria-autocomplete": "list", autocomplete: "off",
                      autofocus: true, placeholder: @placeholder, "aria-label": @placeholder)
                  ]
                end,
                tag.div(role: "listbox", id: "#{combobox_id}_listbox", class: "UnmagicCombobox__listbox",
                  "aria-label": I18n.t("unmagic.components.command_palette.commands", default: "Commands")) do
                  safe_join [
                    *@groups.each_with_index.map { |(label, group), i| group.render(label, "#{@id}_group_#{i}", combobox_id) },
                    (view.turbo_frame_tag("#{combobox_id}_results") if @src && view.respond_to?(:turbo_frame_tag)),
                    tag.div(I18n.t("unmagic.components.command_palette.empty", default: "No commands"), class: "UnmagicCombobox__message", data: { unmagic_combobox_empty: "" }, hidden: true),
                    (tag.div(I18n.t("unmagic.components.combobox.searching", default: "Searching…"), class: "UnmagicCombobox__message", data: { unmagic_combobox_searching: "" }, hidden: true) if @src)
                  ].compact
                end,
                tag.p(class: "UnmagicCombobox__status UnmagicVisuallyHidden", role: "status")
              ]
            end
          end
        end
      end

      # The commands alone, for a remote search's response.
      def results
        frame = view.respond_to?(:turbo_frame_request_id) ? view.turbo_frame_request_id : nil
        combobox_id = frame&.delete_suffix("_results") || "#{@id}_combobox"
        list = safe_join(@groups.each_with_index.map { |(label, group), i| group.render(label, "#{combobox_id}_remote_group_#{i}", combobox_id) })
        frame ? view.turbo_frame_tag(frame) { list } : list
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      class Group
        def initialize(view)
          @view = view
          @commands = []
        end

        def link(name, url, keywords: nil, hint: nil, shortcut: nil, icon: nil, **options)
          target = @view.link_to(url, **options, tabindex: -1, class: @view.class_names("UnmagicCommandPalette__target", options[:class])) { label(name, icon) }
          @commands << { name: name, keywords: keywords, hint: hint, shortcut: shortcut, target: target, kind: "link" }
          nil
        end

        def button(name, url, keywords: nil, hint: nil, shortcut: nil, icon: nil, **options)
          target = @view.button_to(url, **options, tabindex: -1, form_class: "UnmagicCommandPalette__form",
            class: @view.class_names("UnmagicCommandPalette__target", options[:class])) { label(name, icon) }
          @commands << { name: name, keywords: keywords, hint: hint, shortcut: shortcut, target: target, kind: "button" }
          nil
        end

        def render(title, id, combobox_id)
          @view.tag.div(role: "group", class: "UnmagicCombobox__group", "aria-labelledby": id) do
            @view.safe_join [
              @view.tag.div(title, class: "UnmagicCombobox__group-label", id: id),
              *@commands.each_with_index.map do |command, i|
                @view.tag.div(role: "option", id: "#{id}_option_#{i}", class: "UnmagicCombobox__option UnmagicCommandPalette__command",
                  data: { label: command[:name], keywords: command[:keywords], command: command[:kind] }.compact, "aria-selected": "false") do
                  @view.safe_join [
                    command[:target],
                    (@view.tag.span(command[:hint], class: "UnmagicCommandPalette__hint") if command[:hint]),
                    (@view.tag.span(@view.kbd(*command[:shortcut]), class: "UnmagicCommandPalette__shortcut") if command[:shortcut])
                  ].compact
                end
              end
            ]
          end
        end

        private

        def label(name, icon)
          glyph = icon.is_a?(Symbol) ? Icons.svg(@view, icon) : icon
          glyph ? @view.safe_join([ glyph, name ]) : name
        end
      end
    end
  end
end
