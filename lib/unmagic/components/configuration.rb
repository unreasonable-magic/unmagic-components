# frozen_string_literal: true

module Unmagic
  module Components
    # The seams the components render through. Each is a callable, and each has a
    # working default, so the gem depends on no host helper and on no pagination
    # library. An app that already owns these concerns points them at its own
    # versions in an initializer.
    class Configuration
      attr_writer :empty_state, :pagination, :pagy_for, :submit_class, :modal_frame_id, :flash_tones

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
    end
  end
end
