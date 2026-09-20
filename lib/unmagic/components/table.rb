# frozen_string_literal: true

module Unmagic
  module Components
    # Collects the column definitions a `table_for` block declares, then renders
    # them as a TableTag. See ActionViewHelpers#table_for for the public API.
    class Table
      SKELETON_ROWS = 8

      # A pinned column sizes its bar as a fraction of itself; a content-sized one
      # has no width to take a fraction of, so it falls back to a fixed bar.
      SKELETON_WIDTHS = %w[8rem 5rem 7rem 4rem 6rem].freeze
      SKELETON_FRACTIONS = %w[75% 50% 66% 40% 80%].freeze

      def initialize(view, collection, headers: true, sorted_by: nil, sort_direction: nil,
                     sort_url: nil, row_class: nil, rows_id: nil, row_id: nil, **attributes)
        @view = view
        @collection = collection
        @headers = headers
        @attributes = attributes
        @rows_id = rows_id
        @row_id = row_id
        @sort_url = sort_url
        @row_class = row_class
        @sorted_by = (sorted_by || view.params[:sort]).presence&.to_s
        @sort_direction = (sort_direction || view.params[:direction]).presence&.to_sym
        @columns = []
      end

      def column(title = nil, attribute = nil, **options, &block)
        @columns << Column.new(title: title, attribute: attribute, block: block, **options)
        nil
      end

      # A full-width companion row rendered under a record's own. The block runs
      # per record inside one colspan cell; rendering nothing skips the row, so
      # other records stay single-line. The record row drops its bottom border so
      # the pair reads as one row.
      def details(&block)
        @details_block = block
        nil
      end

      # The blank slate for a genuinely empty dataset (no search/filter applied) —
      # typically a prompt to create the first record.
      # Any extra options are handed to the configured empty_state seam, so an
      # app whose blank slate takes more than text (an icon, say) can ask for it
      # per table.
      def empty(text = nil, **options, &block)
        @empty_text = text
        @empty_block = block
        @empty_options = options
        nil
      end

      # The blank slate shown when a search/filter matched nothing, so a
      # filtered-to-zero table doesn't read as "create your first one". Only
      # reached when the collection reports filtered?.
      def no_results(text = nil, **options, &block)
        @no_results_text = text
        @no_results_block = block
        @no_results_options = options
        nil
      end

      def render(pagy: nil, turbo_frame: nil)
        @turbo_frame = turbo_frame

        if @collection.blank?
          empty_slate
        else
          safe_join [ table, pagination(pagy) ].compact
        end
      end

      # The same header cells and the same column widths the loaded table renders —
      # only the body is stand-in bars — so the frame swaps rows in without
      # shifting the columns.
      def skeleton
        view.table_tag (skeleton_header_cells if @headers), skeleton_rows,
          **table_attributes, widths: widths, caption: "Loading…", role: "status", "aria-busy": "true"
      end

      # The <tr> this table would render for one record, on its own — what a
      # broadcast upserts into the tbody. The companion details row is left out:
      # a stream action carries one element, and the pair is a page-render concern.
      def row(record)
        TableTag.new(view, nil, [], labels: labels).render_row(row_hash(record))
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, :link_to, :class_names, to: :view, private: true

      def table
        view.table_tag((header_cells if @headers), row_data, widths: widths, rows_id: @rows_id, labels: labels, **table_attributes)
      end

      def labels = @columns.map { |column| column.title.to_s }

      # Anything the caller put on table_for beyond the builder's own options rides
      # on the <table>, so a view can space, identify or annotate it without
      # wrapping it in a div.
      def table_attributes = @attributes

      # A record collection's columns/rows recast as the plain cells table_tag
      # renders: the header carries its sort link and aria-sort, each row its dom
      # id and row_class.
      def header_cells
        @columns.map do |column|
          { content: header_label(column), class: column.header_classes, "aria-sort": aria_sort(column) }
        end
      end

      def widths = @columns.map(&:width)

      def row_data
        @collection.flat_map do |record|
          details = details_content(record)
          row = row_hash(record, has_details: details.present?)
          details.present? ? [ row, details_row(record, details) ] : [ row ]
        end
      end

      def row_hash(record, has_details: false)
        {
          cells: @columns.map { |column| { content: cell_content(column, record), class: column.cell_classes } },
          id: row_id(record),
          class: class_names(@row_class&.call(record), "has-details" => has_details).presence
        }
      end

      def details_content(record)
        view.capture(record, &@details_block) if @details_block
      end

      def details_row(record, content)
        {
          cells: [ { content: content, colspan: @columns.size } ],
          class: class_names("UnmagicTable__details", @row_class&.call(record))
        }
      end

      def header_label(column)
        column.sort ? sort_link(column) : column.title
      end

      def aria_sort(column)
        if column.sort && sorted_by?(column)
          sorted_direction(column) == :asc ? "ascending" : "descending"
        end
      end

      def sort_link(column)
        next_direction = sorted_by?(column) ? opposite(sorted_direction(column)) : column.direction

        link_to sort_url(column.sort, next_direction), class: "UnmagicTable__sort", data: frame_data do
          safe_join [ column.title, sort_arrow(column) ].compact, " "
        end
      end

      def sort_arrow(column)
        tag.span(sorted_direction(column) == :asc ? "↑" : "↓", "aria-hidden": "true") if sorted_by?(column)
      end

      def sorted_by?(column) = @sorted_by == column.sort.to_s

      def sorted_direction(column)
        if sorted_by?(column)
          @sort_direction || column.direction
        else
          column.direction
        end
      end

      def opposite(direction) = direction == :asc ? :desc : :asc

      def sort_url(key, direction)
        if @sort_url
          @sort_url.call(key, direction)
        else
          query = view.request.query_parameters.except("page").merge("sort" => key, "direction" => direction)
          "#{view.request.path}?#{query.to_query}"
        end
      end

      # dom_id by default. A live table over a mixed collection needs to say
      # otherwise: dom_id names the record's own class, so an STI table's ids carry
      # different prefixes and sort by type rather than by id — which is the order
      # the upsert action inserts on.
      def row_id(record)
        if @row_id
          @row_id.call(record)
        elsif record.respond_to?(:to_key)
          view.dom_id(record)
        end
      end

      def cell_content(column, record)
        if column.block
          view.capture(record, &column.block)
        elsif column.attribute
          record.public_send(column.attribute)
        end
      end

      def empty_slate
        content, options = filtered? ? no_results_slate : empty_dataset_slate
        Components.configuration.empty_state.call(view, content, **options)
      end

      # A search result set knows whether a query/filter was applied; a plain
      # relation or array doesn't, so it's treated as an unfiltered dataset.
      def filtered? = @collection.respond_to?(:filtered?) && @collection.filtered?

      def empty_dataset_slate
        content = @empty_block ? view.capture(&@empty_block) : (@empty_text || "Nothing here yet.")
        [ content, @empty_options || {} ]
      end

      def no_results_slate
        content = @no_results_block ? view.capture(&@no_results_block) : (@no_results_text || "No matching results.")
        [ content, @no_results_options || {} ]
      end

      def pagination(pagy)
        return unless pagy

        Components.configuration.pagination.call(view, pagy: pagy, turbo_frame: @turbo_frame)
      end

      def frame_data
        { turbo_frame: @turbo_frame, turbo_action: "advance" } if @turbo_frame
      end

      def skeleton_header_cells
        @columns.map { |column| { content: column.title, class: column.header_classes } }
      end

      def skeleton_rows
        Array.new(SKELETON_ROWS) do |index|
          @columns.map.with_index { |column, column_index| skeleton_bar(column, index + column_index) }
        end
      end

      def skeleton_bar(column, seed)
        scale = column.width.present? ? SKELETON_FRACTIONS : SKELETON_WIDTHS
        classes = class_names("UnmagicSkeleton", "is-right" => column.right_aligned?)

        tag.div class: classes, style: "width: #{scale[seed % scale.size]}"
      end
    end
  end
end
