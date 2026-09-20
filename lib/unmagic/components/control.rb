# frozen_string_literal: true

module Unmagic
  module Components
    # The class a form control wears, by kind. FormBuilder and control_classes both
    # ask here, and this asks the configured control_class seam, so an app with
    # input styles of its own swaps them in, or opts out, in one place. See
    # ActionViewHelpers#control_classes.
    module Control
      # Each kind of control the components render, and the gem's class for it.
      CLASSES = {
        input: "UnmagicInput",
        text_area: "UnmagicInput",
        password: "UnmagicInput",
        date: "UnmagicInput",
        select: "UnmagicSelect",
        check: "UnmagicCheck",
        radio: "UnmagicRadio",
        switch: "UnmagicSwitch",
        range: "UnmagicRange",
        one_time_code: "UnmagicInput"
      }.freeze

      SIZES = %i[small large].freeze

      # Only the boxes you type into or pick from have a size; a checkbox or radio
      # is sized by the text beside it.
      SIZED = %i[input text_area password date select one_time_code].freeze

      # The classes for a kind of control, or nil when the seam gives none. size:
      # adds the gem's modifier, but only while the gem's own class is in use: an
      # app that swapped in its own classes has no rules for the modifier.
      def self.classes(view, kind, size: nil)
        validate!(kind, size)

        base = Components.configuration.control_class.call(view, kind)
        modifier = "#{CLASSES[kind]}--#{size}" if size && base.to_s.split.include?(CLASSES[kind])
        view.class_names(base, modifier).presence
      end

      # A copy of options with the kind's classes in front of any class: the caller
      # gave, so the caller's can override the gem's.
      def self.merge(view, options, kind)
        options = (options || {}).dup
        given = options.delete(:class) || options.delete("class")

        merged = view.class_names(classes(view, kind), given)
        options[:class] = merged if merged.present?
        options
      end

      def self.validate!(kind, size)
        unless CLASSES.key?(kind)
          raise ArgumentError, "unknown control kind #{kind.inspect} (expected one of #{CLASSES.keys.inspect})"
        end
        return if size.nil?

        unless SIZES.include?(size)
          raise ArgumentError, "unknown control size #{size.inspect} (expected one of #{SIZES.inspect})"
        end
        raise ArgumentError, "a #{kind} control has no size" unless SIZED.include?(kind)
      end
    end
  end
end
