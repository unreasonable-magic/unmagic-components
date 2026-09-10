# frozen_string_literal: true

module ComponentsPreview
  Pager = Struct.new(:previous, :next) do
    def page_url(direction) = "?page=#{direction == :previous ? 1 : 3}"
  end
end
