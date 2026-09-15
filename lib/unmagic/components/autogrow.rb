# frozen_string_literal: true

module Unmagic
  module Components
    # Wraps a textarea in the <unmagic-autogrow> element that grows it with its
    # content. See FormBuilder#autogrow_text_area.
    module Autogrow
      def self.wrap(view, textarea)
        view.content_tag("unmagic-autogrow", textarea, class: "UnmagicAutogrow")
      end
    end
  end
end
