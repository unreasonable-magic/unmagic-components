# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # The browser's pages: the overview, the getting-started pages, and one page
      # per component with every example it lists, live and as source.
      class PagesController < ApplicationController
        before_action :load_fixtures, only: %i[overview component block_preview]

        before_action :load_block, only: %i[block block_preview]

        def blocks
        end

        def block
        end

        def block_preview
        end

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

        def load_block
          @block = BlockCatalog.find(params[:slug])
          raise ActionController::RoutingError, "No block named #{params[:slug]}" unless @block
        end

        # The data examples and thumbnails render from, set for every page that
        # shows either, so any example can use any of it.
        def load_fixtures
          @things = Thing.all
          @pager = Pager.new(5, 7, 6, 12)
          @profile = stored_profile
          @invalid_profile = Profile.new(name: "", role: "Engineer").tap(&:validate)
          @now = Time.current
          @board = board_store
        end
      end
    end
  end
end
