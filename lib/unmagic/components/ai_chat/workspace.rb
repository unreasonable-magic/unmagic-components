# frozen_string_literal: true

module Unmagic
  module Components
    module AIChat
      # The files an agent has put aside while it works, as a folder tree drawn
      # with tree_view. The caller gives paths; the folders come from them. See
      # ActionViewHelpers#ai_chat_workspace.
      class Workspace
        File = Struct.new(:path, :size, :url, :icon)
        Folder = Struct.new(:name, :path, :folders, :files)

        # A glyph per kind of file, from its extension. Anything else is :file.
        FILE_ICONS = {
          file_code: %w[html htm erb haml slim rb js mjs cjs ts tsx jsx css scss sass less py go rs java kt swift c h
                        cc cpp hpp cs php sh bash zsh xml yml yaml toml sql vue svelte],
          file_text: %w[md markdown mdx txt text rtf log pdf doc docx odt],
          file_image: %w[png jpg jpeg gif webp avif svg bmp ico heic tif tiff],
          file_json: %w[json jsonl ndjson geojson],
          file_spreadsheet: %w[csv tsv xls xlsx ods numbers],
          file_archive: %w[zip tar gz tgz bz2 xz 7z rar],
          file_audio: %w[mp3 wav ogg oga flac m4a aac opus],
          file_video: %w[mp4 m4v mov webm mkv avi]
        }.flat_map { |icon, extensions| extensions.map { |extension| [ extension, icon ] } }.to_h.freeze

        def self.icon_for(path)
          FILE_ICONS.fetch(::File.extname(path.to_s).delete_prefix(".").downcase, :file)
        end

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

        # icon: nil picks the glyph from the path's extension.
        def file(path, size: nil, url: nil, icon: nil)
          path = path.to_s
          @files << File.new(path, size, url, icon || self.class.icon_for(path))
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
            tree = TreeView.new(view, label: @title, class: "UnmagicAIChatWorkspace__files")
            add(tree, root)
            tree.render
          end
        end

        # Folders keep the order their first file came in, ahead of the files
        # beside them, which keep the order they came in.
        def root
          Folder.new(nil, nil, {}, []).tap do |root|
            @files.each do |file|
              *directories, _name = segments(file.path)
              folder = directories.inject(root) do |parent, name|
                parent.folders[name] ||= Folder.new(name, [ parent.path, name ].compact.join("/"), {}, [])
              end
              folder.files << file
            end
          end
        end

        def segments(path)
          parts = path.split("/").reject { |part| part.empty? || part == "." }
          parts.empty? ? [ path ] : parts
        end

        # Folders are open, since the point is to see what the agent made. A
        # folder that holds nothing but one folder joins it in one row
        # (captures/example.com/jobs), so a deep path costs one row, not one per
        # level.
        def add(nodes, folder)
          folder.folders.each_value do |child|
            names = [ child.name ]
            while child.files.empty? && child.folders.size == 1
              child = child.folders.values.first
              names << child.name
            end

            nodes.branch(folder_label(names), icon: :folder, open: true, title: child.path,
              class: "UnmagicAIChatWorkspace__folder") { |branch| add(branch, child) }
          end

          folder.files.each do |file|
            nodes.leaf(::File.basename(file.path), href: file.url, icon: file.icon, title: file.path,
              meta: (view.number_to_human_size(file.size) if file.size), class: "UnmagicAIChatWorkspace__file")
          end
        end

        # A joined row keeps its last folder's name whole and lets the ones
        # before it shorten, so the ellipsis never eats the name that matters.
        def folder_label(names)
          return names.first if names.one?

          tag.span(class: "UnmagicAIChatWorkspace__path") do
            safe_join [
              tag.span(names[0...-1].join("/"), class: "UnmagicAIChatWorkspace__directory"),
              tag.span("/#{names.last}", class: "UnmagicAIChatWorkspace__name")
            ]
          end
        end
      end
    end
  end
end
