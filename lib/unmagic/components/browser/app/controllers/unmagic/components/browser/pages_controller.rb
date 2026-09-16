# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # The browser's pages: the overview, the getting-started pages, and one page
      # per component with every example it lists, live and as source.
      class PagesController < ApplicationController
        before_action :load_fixtures, only: %i[overview component]

        def overview
        end

        def installation
        end

        def theming
        end

        def component
          @component = Catalog.find(params[:slug])
          raise ActionController::RoutingError, "No component named #{params[:slug]}" unless @component
        end

        private

        # The data examples and thumbnails render from, set for every page that
        # shows either, so any example can use any of it.
        def load_fixtures
          @things = Thing.all
          @pager = Pager.new(1, 3)
          @profile = stored_profile
          @invalid_profile = Profile.new(name: "", role: "Engineer").tap(&:validate)
          @now = Time.current
          @board = board_store
        end
      end
    end
  end
end
