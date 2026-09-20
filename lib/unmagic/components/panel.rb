# frozen_string_literal: true

require "securerandom"

module Unmagic
  module Components
    # A card with a row of tabs across its top bar and the open tab's content in
    # its body. See ActionViewHelpers#panel.
    class Panel
      def initialize(view, id: nil, flush: false, **options)
        @view = view
        @id = id || "unmagic_panel_#{SecureRandom.hex(4)}"
        @flush = flush
        @options = options
        @tabs = Tabs.new(view, id: @id, style: :bar)
      end

      # The tabs and their panels are Tabs' own, so a panel takes exactly what
      # tabs does: a label, an icon:, a disabled: reason, or an href: for a tab
      # that is a page of its own.
      delegate :tab, :panel, to: :@tabs

      # In-page tabs put the whole card inside <unmagic-tabs>, whose script finds
      # the list in the bar and the panels in the body by their ids. Link tabs
      # need no script, so the card is a plain <section> and the block is the
      # body: the server has already drawn the open one.
      def render(body)
        @tabs.validate!
        links = @tabs.links?

        card = Card.new(view, flush: true, tag_name: (links ? :section : "unmagic-tabs"), **@options, id: @id,
          class: view.class_names("UnmagicPanel", { "UnmagicPanel--flush" => @flush },
            ("UnmagicTabs UnmagicTabs--bar" unless links), @options[:class]))
        card.header(links ? tag.nav(@tabs.list, class: "UnmagicTabs UnmagicTabs--bar") : @tabs.list, class: "UnmagicPanel__bar")
        card.render(links ? body : safe_join(@tabs.panels))
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
