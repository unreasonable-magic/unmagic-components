# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      Pager = Struct.new(:previous, :next) do
        def page_url(direction) = "?page=#{direction == :previous ? 1 : 3}"
      end
    end
  end
end
