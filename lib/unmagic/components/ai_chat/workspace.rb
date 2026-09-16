# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The files an agent has put aside while it works. A flat list for now: a
      # nested tree waits on the gem's tree_view, rather than the gem growing two
      # tree implementations. See ActionViewHelpers#ai_chat_workspace.
      class Workspace
        File = Struct.new(:path, :size, :url, :icon)

        def initialize(view, title: nil, count: nil, open: true, empty: nil, collapsible: true, title_tag: :h2, **options)
          @view = view
          @title = title || AIChat.t("workspace.title", default: "Workspace")
          @count = count
          @open = open
          @empty = empty
          @collapsible = collapsible
          @title_tag = title_tag
          @options = options
          @files = []
        end

        def file(path, size: nil, url: nil, icon: :file)
          @files << File.new(path.to_s, size, url, icon)
          nil
        end

        def render
          count = @count || (@files.size if @files.any?)

          Section.new(view, block: "UnmagicAIChatWorkspace", icon: :folder, title: @title, count: count,
            open: @open, collapsible: @collapsible, title_tag: @title_tag, options: @options).render(body)
        end

        private

        attr_reader :view

        delegate :tag, :safe_join, to: :view, private: true

        def body
          if @files.empty?
            tag.p(@empty || AIChat.t("workspace.empty", default: "No files yet."), class: "UnmagicAIChatWorkspace__empty")
          else
            tag.ul(safe_join(@files.map { |file| item(file) }), class: "UnmagicAIChatWorkspace__files")
          end
        end

        # Not a link without a url: a workspace is usually read-only, and a link
        # that goes nowhere is worse than plain text.
        def item(file)
          name = ::File.basename(file.path)
          directory = ::File.dirname(file.path)

          row = safe_join [
            Icons.svg(view, file.icon, class: "UnmagicAIChatWorkspace__icon"),
            tag.span(class: "UnmagicAIChatWorkspace__name") do
              safe_join [
                (tag.span("#{directory}/", class: "UnmagicAIChatWorkspace__directory") unless directory == "."),
                name
              ].compact
            end,
            (tag.span(view.number_to_human_size(file.size), class: "UnmagicAIChatWorkspace__size") if file.size)
          ].compact

          tag.li(class: "UnmagicAIChatWorkspace__file", title: file.path) do
            file.url ? view.link_to(row, file.url, class: "UnmagicAIChatWorkspace__link") : row
          end
        end
      end
    end
  end
end
