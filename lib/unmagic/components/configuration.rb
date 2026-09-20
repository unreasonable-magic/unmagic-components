# frozen_string_literal: true

module Unmagic
  module Components
    # The seams the components render through. Each is a callable, and each has a
    # working default, so the gem depends on no host helper and on no pagination
    # library. An app that already owns these concerns points them at its own
    # versions in an initializer.
    class Configuration
      attr_writer :empty_state, :pagination, :pagy_for, :submit_class, :control_class, :modal_frame_id, :flash_tones,
        :highlight, :code_block, :sortable_item, :sortable_url

      # The tone each flash type's toast wears, keyed by the flash type as a string.
      # A type that isn't listed is :info.
      def flash_tones
        @flash_tones ||= {
          "notice" => :good, "success" => :good,
          "alert" => :bad, "error" => :bad,
          "warning" => :warn,
          "info" => :info
        }
      end

      # The id of the turbo frame the shared modal loads into — what modal_link_to
      # targets, and what a `dialog` checks to know it is being rendered into the
      # modal.
      def modal_frame_id
        @modal_frame_id ||= "modal"
      end

      # Renders a table's blank slate. Called with (view, content), where content
      # is already-captured markup or a plain string.
      def empty_state
        @empty_state ||= Renderers::EmptyState.default
      end

      # Renders a table's pager. Called with (view, pagy:, turbo_frame:).
      def pagination
        @pagination ||= Renderers::Pagination.default
      end

      # Resolves the pagy object a table should page with. Called with
      # (view, collection); returning nil suppresses the pager.
      def pagy_for
        @pagy_for ||= Renderers::Pagination.default_pagy_for
      end

      # The classes on a form's submit button. Called with (view, variant), so an
      # app can hand back whatever its own button helper produces.
      def submit_class
        @submit_class ||= ->(_view, variant) { "UnmagicButton UnmagicButton--#{variant}" }
      end

      # Colours a block of source. Called with (source, language), where language
      # is a symbol or string such as :json or "ruby", a Rouge lexer, or nil for
      # plain text; returns one html_safe string per line. The default lexes with
      # Rouge and tags each token with Rouge's short class names, which the gem's
      # stylesheet colours. An app with another highlighter hands back its own
      # lines, escaped.
      #
      #   config.highlight = ->(source, language) { MyHighlighter.lines(source, language) }
      def highlight
        @highlight ||= ->(source, language) { Highlight.lines(source, language) }
      end

      # Frames a block of code: a tool call's payload, a failure's backtrace, a
      # code block in prose. Called with (view, source, language) and returns
      # markup. The default is a code_view, coloured through highlight; an app
      # that wants its own box hands back its own.
      #
      #   config.code_block = ->(view, source, language) { view.render("code", source: source, language: language) }
      def code_block
        @code_block ||= ->(view, source, language) { view.code_view(source, language: language, copy: false) }
      end

      # What a sortable item carries for a record: its key and its rank. Called with
      # (view, record); returns { key:, rank: }. unmagic-sortable sets this to its
      # signed, scoped keys; the default is the record's id and sortable_rank.
      def sortable_item
        @sortable_item ||= lambda do |_view, record|
          rank = record.try(:sortable_rank)
          { key: record.to_param, rank: rank.is_a?(BigDecimal) ? rank.to_s("F") : rank&.to_s }
        end
      end

      # Where a sortable list posts a drop when it isn't given url:. Called with
      # (view); nil means a drop only fires unmagic-sortable:move for your own script.
      # unmagic-sortable points it at its endpoint.
      def sortable_url
        @sortable_url ||= ->(_view) { nil }
      end

      # The classes on a form control. Called with (view, kind), where kind is one
      # of Control::CLASSES' keys (:input, :select, :check…); return an app's own
      # classes, or nil to leave the control unstyled.
      def control_class
        @control_class ||= ->(_view, kind) { Control::CLASSES.fetch(kind) }
      end
    end
  end
end
