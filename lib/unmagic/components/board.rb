# frozen_string_literal: true

module Unmagic
  module Components
    # A Trello-style board: columns of cards, both reorderable, with a way to add
    # to each. Built from sortable lists, so it posts the same drops. See
    # ActionViewHelpers#board.
    class Board
      def initialize(view, id:, url: nil, columns_url: nil, sortable_columns: true, label: nil, column_height: nil,
        **options)
        raise ArgumentError, "board needs an id: (it names the board's lists)" if id.blank?

        @view = view
        @id = id.to_s
        @url = url
        @columns_url = columns_url.nil? ? url : columns_url
        @sortable_columns = sortable_columns
        @label = label || I18n.t("unmagic.components.board.label", default: "Board")
        @column_height = column_height
        @options = options
        @columns = []
        @add_column = nil
      end

      def column(record = nil, title:, key: nil, rank: nil, params: {}, count: nil, &block)
        builder = Column.new(view, self, record: record, title: title, key: key, rank: rank, params: params, count: count)
        view.capture(builder, &block) if block
        @columns << builder
        nil
      end

      # The tile at the end of the board that adds a column.
      def add_column(url:, field:, label: nil, placeholder: nil, params: {}, method: :post)
        label ||= I18n.t("unmagic.components.board.add_column", default: "Add a list")
        @add_column = Board.add_form(view, id: "#{@id}_add_column", url: url, field: field, label: label,
          placeholder: placeholder,
          params: params, method: method, submit: I18n.t("unmagic.components.board.add_column_submit", default: "Add list"),
          class: "UnmagicBoard__addColumn")
        nil
      end

      attr_reader :id, :url

      def cards_namespace = "#{id}-cards"

      def render
        # --unmagic-board-column-height is the board's one knob: how tall a column
        # grows before its cards scroll.
        style = [ @options[:style], ("--unmagic-board-column-height: #{@column_height}" if @column_height) ].compact.join("; ")

        view.content_tag(:div, **@options, id: @id, role: "region", "aria-label": @label, style: style.presence,
          class: view.class_names("UnmagicBoard", @options[:class])) do
          if @sortable_columns
            list = Sortable::List.new(view, namespace: "#{@id}-columns", url: @columns_url, orientation: :horizontal,
              label: @label, class: "UnmagicBoard__columns")
            @columns.each { |column| column.add_to(list) }
            list.render(@add_column && view.tag.div(@add_column, class: "UnmagicBoard__tail", "data-sortable-tail": ""))
          else
            view.tag.div(class: "UnmagicBoard__columns") do
              view.safe_join [ *@columns.map { |column| view.tag.div(column.panel(handle: false), class: "UnmagicBoard__column") },
                (view.tag.div(@add_column, class: "UnmagicBoard__tail") if @add_column) ].compact
            end
          end
        end
      end

      # A <details> that opens into a one-field form: Trello's "Add a card". Enter
      # submits, Escape closes, and it stays open after adding so several can be
      # added in a row (board.js).
      #
      # The field has a stable id so a morph refresh keeps the same element, and with
      # it the focus, after each add.
      def self.add_form(view, id:, url:, field:, label:, placeholder:, params:, method:, submit:, **options)
        view.tag.details(**options, class: view.class_names("UnmagicBoard__add", options[:class])) do
          view.safe_join [
            view.tag.summary(class: "UnmagicBoard__addToggle") do
              view.safe_join [ Icons.svg(view, :plus), label ]
            end,
            view.form_with(url: url, method: method, class: "UnmagicBoard__addForm", data: { board_add: "" }) do
              view.safe_join [
                *params.map { |name, value| view.hidden_field_tag(name, value, id: nil) },
                Autogrow.wrap(view, view.text_area_tag(field, nil, Control.merge(view, {
                  id: id, rows: 2, required: true, placeholder: placeholder || label, "aria-label": label,
                  "data-board-add-field": "", class: "UnmagicBoard__addField"
                }, :text_area))),
                view.tag.div(class: "UnmagicBoard__addActions") do
                  cancel = I18n.t("unmagic.components.board.cancel", default: "Cancel")
                  view.safe_join [
                    view.tag.button(submit, type: "submit", class: Button.classes(:primary, size: :small)),
                    view.tag.button(Icons.svg(view, :x), type: "button", "data-board-add-cancel": "",
                      "aria-label": cancel, title: cancel, class: Button.classes(:icon))
                  ]
                end
              ]
            end
          ]
        end
      end

      private

      attr_reader :view

      # One column: a header that is its drag handle, a sortable list of cards, and
      # an add-card form.
      class Column
        def initialize(view, board, record:, title:, key:, rank:, params:, count:)
          @view = view
          @board = board
          @record = record
          @title = title
          @key = key
          @rank = rank
          @params = params
          @count = count
          @cards = Sortable::List.new(view, namespace: board.cards_namespace, params: params, url: board.url,
            label: title, class: "UnmagicBoard__cards")
          @card_count = 0
          @actions = nil
          @add = nil
          # Stable across renders, so a morph matches the column's elements up.
          @dom_id = "#{board.id}_column_#{(key || record&.to_param || title).to_s.parameterize(separator: "_")}"
        end

        def card(record = nil, key: nil, rank: nil, label: nil, **options, &block)
          @card_count += 1
          @cards.item(record, key: key, rank: rank, label: label, **options,
            class: view.class_names("UnmagicBoard__card", options[:class]), &block)
        end

        def actions(content = nil, &block)
          @actions = block ? view.capture(&block) : content
          nil
        end

        def add(url:, field:, label: nil, placeholder: nil, params: {}, method: :post)
          label ||= I18n.t("unmagic.components.board.add_card", default: "Add a card")
          @add = Board.add_form(view, id: "#{@dom_id}_add", url: url, field: field, label: label,
            placeholder: placeholder, params: params,
            method: method, submit: I18n.t("unmagic.components.board.add_card_submit", default: "Add card"))
          nil
        end

        def add_to(list)
          list.item(@record, key: @key, rank: @rank, label: @title, class: "UnmagicBoard__column") { panel(handle: true) }
        end

        # The header is where a column is picked up by pointer; the grip inside it is
        # its keyboard stop. The header's own buttons stay clickable.
        def panel(handle:)
          view.tag.section(class: "UnmagicBoard__panel", "aria-labelledby": "#{@dom_id}_title") do
            view.safe_join [
              view.tag.header(class: "UnmagicBoard__head", "data-sortable-handle": (handle ? "" : nil)) do
                view.safe_join [
                  (Sortable.handle(view, label: I18n.t("unmagic.components.board.move_column", title: @title,
                    default: "Move %{title}"), class: "UnmagicBoard__grip") if handle),
                  view.tag.h3(@title, id: "#{@dom_id}_title", class: "UnmagicBoard__title"),
                  count,
                  (view.tag.div(@actions, class: "UnmagicBoard__actions") if @actions.present?)
                ].compact
              end,
              @cards.render,
              @add
            ].compact
          end
        end

        private

        attr_reader :view

        def count
          number = @count || @card_count
          noun = I18n.t("unmagic.components.board.cards", count: number, default: number == 1 ? "card" : "cards")
          view.tag.span(class: "UnmagicBoard__count") do
            view.safe_join [ number.to_s, view.tag.span(" #{noun}", class: "UnmagicVisuallyHidden") ]
          end
        end
      end
    end
  end
end
