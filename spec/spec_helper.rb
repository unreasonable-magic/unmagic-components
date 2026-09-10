# frozen_string_literal: true

require "logger"
require "nokogiri"
require "rails"
require "active_model"
require "action_controller/railtie"
require "action_view/railtie"
require "turbo-rails"

require "unmagic/components"

# A Rails application small enough to live in this file. The components are
# ActionView helpers that read params, the request and the controller, so the
# specs need a real view context — but nothing about a whole spec/dummy tree.
module Unmagic
  module Components
    class SpecApplication < ::Rails::Application
      config.eager_load = false
      config.root = File.expand_path("..", __dir__)
      config.secret_key_base = "unmagic-components-spec"
      config.logger = Logger.new(IO::NULL)
    end
  end
end

Rails.application.initialize!

Rails.application.routes.draw do
  root to: "things#index"
end

class ThingsController < ActionController::Base
  include Rails.application.routes.url_helpers

  # Column partials for the live-table specs live under spec/views.
  append_view_path File.expand_path("views", __dir__)
end

# A record with validations, for the form specs.
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :name, :string
  attribute :terms, :boolean

  validates :email, presence: true
end

# A row that is not an Active Record, to keep the specs database-free while
# still exercising dom_id.
class Thing
  include ActiveModel::Model
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :id, :name, :score

  def to_key = [ id ]
  def persisted? = id.present?
end

module ViewHelpers
  # Builds a real view context. `params`, `path` and `query` drive sort links and
  # the deferred frame's src; `turbo_frame` simulates the Turbo-Frame header the
  # second request carries.
  def build_view(params: {}, path: "/things", query: {}, turbo_frame: nil)
    query_string = query.to_query
    env = ::Rack::MockRequest.env_for("http://test.host#{path}#{"?#{query_string}" unless query_string.empty?}")
    env["HTTP_TURBO_FRAME"] = turbo_frame if turbo_frame

    request = ActionDispatch::Request.new(env)
    controller = ThingsController.new
    controller.set_request!(request)
    controller.set_response!(ThingsController.make_response!(request))
    controller.params = ActionController::Parameters.new(query.merge(params))

    controller.view_context
  end

  # A form bound to the extracted builder.
  def build_form(object = Signup.new, view: build_view, &block)
    view.form_with(model: object, url: "/signups", builder: Unmagic::Components::FormBuilder, &block)
  end

  # The builder on its own, for the methods that don't render a form.
  def build_form_builder(object, view: build_view)
    Unmagic::Components::FormBuilder.new(:signup, object, view, {})
  end

  def html(markup)
    Nokogiri::HTML5.fragment(markup.to_s)
  end

  # A bare <tr> is dropped by HTML5 fragment parsing, which only keeps table rows
  # inside a table. Broadcast rows are rendered on their own, so give them one.
  def html_row(markup)
    Nokogiri::HTML5.fragment("<table><tbody>#{markup}</tbody></table>")
  end

  def things(count = 2)
    Array.new(count) { |i| Thing.new(id: i + 1, name: "Thing #{i + 1}", score: (i + 1) * 10) }
  end
end

RSpec.configure do |config|
  config.include ViewHelpers

  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  Kernel.srand config.seed

  config.after { Unmagic::Components.reset_configuration! }
end
