# frozen_string_literal: true

module Unmagic
  module Components
    class DetailList
      class Item
        attr_reader :label, :block

        def initialize(label:, value:, block:, span: nil, **options)
          @label = label
          @value = value
          @block = block
          @span = span
          @classes = options[:class]
        end

        def full_span? = @span == :full

        # A blank value renders as an em dash, so call sites don't need their own
        # `.presence || "—"`.
        def value
          @value.presence || "—"
        end

        def dd_classes(base = nil)
          [ base, @classes ].compact.presence&.join(" ")
        end
      end
    end
  end
end
