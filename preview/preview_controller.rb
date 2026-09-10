# frozen_string_literal: true

class PreviewController < ActionController::Base
  append_view_path File.expand_path("views", __dir__)
  layout "preview"

  def index
    @things = ComponentsPreview::Thing.all
  end

  def deferred
    @things = ComponentsPreview::Thing.all
  end
end
