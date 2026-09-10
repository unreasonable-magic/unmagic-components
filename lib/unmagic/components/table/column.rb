# frozen_string_literal: true

module Unmagic
  module Components
    class Table
      class Column
        attr_reader :title, :attribute, :sort, :direction, :block, :width

        def initialize(title:, attribute:, block:, sort: nil, direction: :asc, align: nil,
                       numeric: false, width: nil, **options)
          @title = title
          @attribute = attribute
          @block = block
          @sort = sort
          @direction = direction.to_sym
          @align = align
          @numeric = numeric
          @width = width
          @classes = options[:class]
        end

        def right_aligned? = @align == :right || @numeric

        def centered? = @align == :center

        def header_classes
          alignment
        end

        def cell_classes
          [ alignment, ("is-numeric" if @numeric), @classes ].compact.presence&.join(" ")
        end

        private

        def alignment
          if right_aligned?
            "is-right"
          elsif centered?
            "is-center"
          end
        end
      end
    end
  end
end
