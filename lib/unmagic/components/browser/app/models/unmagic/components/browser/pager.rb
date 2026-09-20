# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # What the pagination examples page over: enough of Pagy's API to draw the
      # arrows, and with a page and a last, the numbers too.
      Pager = Struct.new(:previous, :next, :page, :last) do
        def page_url(target)
          case target
          when :previous then "?page=#{previous}"
          when :next then "?page=#{self.next}"
          else "?page=#{target}"
          end
        end
      end
    end
  end
end
