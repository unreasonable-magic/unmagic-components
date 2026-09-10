# frozen_string_literal: true

module Unmagic
  module Components
    # Renders a `.UnmagicTable` from plain cells. This is the primitive Table is
    # built on, and it is useful directly for a static table that wants the same
    # look without the record/sort/pagination machinery.
    #
    # A cell is a value, or a { content:, **attrs } hash setting attributes on its
    # th/td. A row is an array of cells, or a { cells:, **attrs } hash setting
    # attributes on its <tr>.
    class TableTag
      ALIGN_CLASSES = { right: "is-right", center: "is-center" }.freeze

      # A width is either a CSS length, which rides on the <col> as an inline
      # style, or anything else, which is treated as a class name so a host can
      # pin columns with its own utilities (e.g. Tailwind's "w-[40%]").
      CSS_LENGTH = /\A-?[\d.]+(%|px|rem|em|ch|ex|vw|vh|fr)\z/

      def initialize(view, headers, rows, aligns: [], widths: [], caption: nil, rows_id: nil, **attributes)
        @view = view
        @headers = headers
        @rows = rows
        @aligns = aligns
        @widths = widths
        @caption = caption
        @rows_id = rows_id
        @attributes = attributes
      end

      def render
        attributes = @attributes.dup
        attributes[:class] = class_names("UnmagicTable UnmagicTable--full",
          ("UnmagicTable--fixed" if pinned?), attributes[:class])

        tag.table(**attributes) do
          safe_join [ caption, colgroup, (head if @headers.present?), body ].compact
        end
      end

      # One <tr>, rendered on its own. A broadcast replacing or inserting a single
      # row needs the same markup the table would have produced for it.
      def render_row(row)
        row = { cells: row } unless row.is_a?(Hash)
        cells = Array(row[:cells]).each_with_index.map { |cell, index| render_cell(:td, cell, @aligns[index]) }
        tag.tr safe_join(cells), **row.except(:cells)
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, :class_names, to: :view, private: true

      def pinned? = @widths.any?(&:present?)

      def caption
        tag.caption(@caption, class: "UnmagicTable__caption") if @caption
      end

      def colgroup
        return unless pinned?

        tag.colgroup safe_join(@widths.map { |width| col(width) })
      end

      def col(width)
        if width.blank?
          tag.col
        elsif width.to_s.match?(CSS_LENGTH)
          tag.col(style: "width: #{width}")
        else
          tag.col(class: width)
        end
      end

      def head
        tag.thead tag.tr(safe_join(@headers.each_with_index.map { |cell, index| render_cell(:th, cell, @aligns[index]) }))
      end

      def body
        tag.tbody safe_join(@rows.map { |row| render_row(row) }), id: @rows_id
      end

      def render_cell(name, cell, align)
        cell = { content: cell } unless cell.is_a?(Hash)
        attributes = cell.except(:content)
        attributes[:class] = class_names(ALIGN_CLASSES[align], attributes[:class]).presence
        tag.public_send(name, cell[:content], **attributes)
      end
    end
  end
end
