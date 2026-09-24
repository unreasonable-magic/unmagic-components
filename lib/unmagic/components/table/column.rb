# frozen_string_literal: true

module Unmagic
  module Components
    class Table
      class Column
        attr_reader :title, :attribute, :sort, :direction, :block, :width, :skeleton

        def initialize(title:, attribute:, block:, sort: nil, direction: :asc, align: nil,
                       numeric: false, width: nil, skeleton: nil, **options)
          @title = title
          @attribute = attribute
          @block = block
          @sort = sort
          @direction = direction.to_sym
          @align = align
          @numeric = numeric
          @width = width
          @classes = options[:class]
          @skeleton = validate_skeleton(skeleton)
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

        # A skeleton builder shape by name, or a callable given the builder.
        def validate_skeleton(skeleton)
          return skeleton if skeleton.nil? || skeleton.respond_to?(:call)
          return skeleton if Skeleton::SHAPES.include?(skeleton)

          raise ArgumentError, "unknown skeleton shape #{skeleton.inspect} (expected one of #{Skeleton::SHAPES.inspect})"
        end

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
