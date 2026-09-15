# frozen_string_literal: true

require "active_support/concern"

module Unmagic
  module Components
    # The success response for a create or update whose form opened in the frame
    # modal. A turbo_stream.refresh morphs the page in place — updating the list the
    # dialog was launched from — and the modal closes in that same render, so the
    # page repaints once, straight to the new state. A visit without Turbo falls back
    # to a plain redirect.
    #
    #   class LabelsController < ApplicationController
    #     include Unmagic::Components::DialogResponder
    #
    #     def update
    #       if @label.update(label_params)
    #         refresh_or_redirect labels_path, notice: "Label saved."
    #       else
    #         render :edit, status: :unprocessable_content
    #       end
    #     end
    #   end
    #
    # The request_id is dropped so the refresh isn't suppressed on the very tab that
    # submitted it — Turbo's guard against echoing a tab's own broadcasts keys off it.
    #
    # A plain redirect_to works from a modal form too: the modal visits the page it
    # lands on and closes. The refresh is the smoother of the two, keeping scroll
    # position and any state the page holds.
    module DialogResponder
      extend ActiveSupport::Concern

      private

      def refresh_or_redirect(url, **flash_options)
        flash_options.each { |type, message| flash[type] = message }

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
          format.html { redirect_to url }
        end
      end
    end
  end
end
