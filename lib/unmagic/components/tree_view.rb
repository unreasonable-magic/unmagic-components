# frozen_string_literal: true

module Unmagic
  module Components
    # A nested, collapsible list of things inside other things: nested lists and
    # <details>, no script. See ActionViewHelpers#tree_view.
    class TreeView
      # What tree_view and every branch yield: branch and leaf record a node and
      # return nil. A branch collects its children with the same builder, so the
      # tree is whole before anything renders and open: can default from below.
      class Nodes
        Branch = Struct.new(:label, :icon, :open, :meta, :options, :children)
        Leaf = Struct.new(:label, :href, :icon, :current, :meta, :options)

        attr_reader :items

        def initialize(view)
          @view = view
          @items = []
        end

        def branch(label, icon: nil, open: nil, meta: nil, **options, &block)
          children = Nodes.new(@view)
          @view.capture(children, &block) if block
          @items << Branch.new(label, icon, open, meta, options, children)
          nil
        end

        def leaf(label = nil, href: nil, icon: nil, current: false, meta: nil, **options, &block)
          label = @view.capture(&block) if block
          @items << Leaf.new(label, href, icon, current, meta, options)
          nil
        end

        def current?
          items.any? { |item| item.is_a?(Leaf) ? item.current : item.children.current? }
        end
      end

      def initialize(view, label:, guides: true, **options)
        raise ArgumentError, "tree_view needs a label:" if label.blank?

        @view = view
        @label = label
        @guides = guides
        @options = options
        @nodes = Nodes.new(view)
      end

      delegate :branch, :leaf, to: :@nodes

      def render
        return if @nodes.items.empty?

        classes = view.class_names("UnmagicTree", { "UnmagicTree--guides" => @guides }, @options[:class])
        tag.ul(list(@nodes), **@options, "aria-label": @label, class: classes)
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true

      def list(nodes)
        safe_join(nodes.items.map do |item|
          tag.li(item.is_a?(Nodes::Branch) ? branch_node(item) : leaf_node(item), class: "UnmagicTree__node")
        end)
      end

      # A branch without an explicit open: is open when it leads to the current
      # leaf, so the useful path is showing on load and after a morph.
      def branch_node(branch)
        open = branch.open.nil? ? branch.children.current? : branch.open
        toggle = Icons.svg(view, :chevron_right, class: "UnmagicTree__toggle")
        summary = tag.summary(safe_join([ toggle, *row_content(branch) ]), **row_options(branch, "UnmagicTree__row"))
        panel = if branch.children.items.empty?
          tag.p(I18n.t("unmagic.components.tree.empty", default: "Empty"), class: "UnmagicTree__empty")
        else
          tag.ul(list(branch.children), class: "UnmagicTree__children")
        end

        tag.details(safe_join([ summary, panel ]), class: "UnmagicTree__branch", open: open || nil)
      end

      # A link with href:, plain text without: a row that goes nowhere shouldn't
      # look or behave like it goes somewhere.
      def leaf_node(leaf)
        options = row_options(leaf, "UnmagicTree__row", "UnmagicTree__row--leaf")
        options[:"aria-current"] = "page" if leaf.current
        content = safe_join(row_content(leaf))

        leaf.href ? view.link_to(content, leaf.href, **options) : tag.span(content, **options)
      end

      def row_content(node)
        [
          (Icons.svg(view, node.icon, class: "UnmagicTree__icon") if node.icon),
          tag.span(node.label, class: "UnmagicTree__label"),
          (tag.span(node.meta, class: "UnmagicTree__meta") if node.meta.present?)
        ].compact
      end

      # A string label that truncates still has its whole text in title; markup
      # doesn't, so the caller gives one.
      def row_options(node, *classes)
        title = node.options.fetch(:title) { node.label unless node.label.html_safe? }
        node.options.merge(title: title, class: view.class_names(*classes, node.options[:class]))
      end
    end
  end
end
