# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # What the interactive examples talk to: the dialogs, the toasts, the board
      # and the AI chat composer. Everything they change lives in the visitor's
      # session.
      class DemosController < ApplicationController
        FLASH_TYPES = %w[notice alert warning info].freeze

        def edit_profile
          @profile = stored_profile
        end

        def update_profile
          @profile = Profile.new(params.require(:profile).permit(:name, :role))

          if @profile.valid?
            browser_session[:profile] = @profile.attributes
            refresh_or_redirect component_path("dialog"), notice: "Profile saved."
          else
            render :edit_profile, status: 422
          end
        end

        def destroy_profile
          browser_session.delete(:profile)
          redirect_to component_path("confirm"), status: :see_other, notice: "Profile reset."
        end

        # The combobox example's search: the team, filtered by ?q=.
        def search_things
          q = params[:q].to_s.downcase
          @things = Thing.all.select { |thing| "#{thing.name} #{thing.role}".downcase.include?(q) }
        end

        # The command palette's remote commands: kilns matching ?q=.
        def search_commands
          q = params[:q].to_s.downcase
          @kilns = %w[saberpc studio-kiln render-farm-1].select { |kiln| kiln.include?(q) || "kiln".include?(q) }
        end

        # Slow enough to watch the skeleton before the form arrives.
        def slow_dialog
          sleep 1.5
          @profile = stored_profile
          render :edit_profile
        end

        # An empty error response: the case Turbo ignores unless the modal catches it.
        def forbidden_dialog
          head :forbidden
        end

        def flash_toast
          type = FLASH_TYPES.include?(params[:type]) ? params[:type] : "notice"
          flash[type] = params[:message]
          redirect_to component_path("toast"), status: :see_other
        end

        def stream_toast
          tone = Toast::TONES.map(&:to_s).include?(params[:tone]) ? params[:tone].to_sym : :good
          @toast_options = { tone: tone }
          @toast_options[:position] = params[:position].to_sym if Toast::POSITIONS.map(&:to_s).include?(params[:position])
          @toast_options[:duration] = params[:duration].to_i if params[:duration].to_s.match?(/\A\d+\z/)
          @toast_options[:width] = params[:width].to_sym if Toast::WIDTHS.keys.map(&:to_s).include?(params[:width])
          @toast_options[:width] = 440 if params[:width] == "440"
          @toast_options[:layout] = :vertical if params[:layout] == "vertical"
          @toast_options[:target] = "toast_panel" if params[:example] == "boundaries"
          if params[:example] == "javascript_rails"
            @toast_options.merge!(toast_id: "browser-export-#{SecureRandom.hex(4)}", duration: 0)
          end
          render :stream_toast, formats: [ :turbo_stream ]
        end

        # The board example's server, answering as unmagic-sortable's endpoint does:
        # a refresh, which morphs the page to the order that was saved.
        def board_order
          moved = board_store.move(params[:moved], prev: params[:prev], following: params[:next], column: params[:column])
          board_refresh(moved ? :ok : :not_found)
        end

        def board_card
          board_store.add_card(params.dig(:card, :title), params.dig(:card, :column))
          board_refresh
        end

        def board_column
          board_store.add_column(params.dig(:column, :title))
          board_refresh
        end

        def board_reset
          board_store.reset!
          redirect_to component_path("board"), status: :see_other
        end

        # The composer example's server: confirm the question under the id the form
        # minted, then hand the page a reply to play back as a model would stream
        # it. The browser has no Action Cable, so the flushes ride along in the
        # response and a small driver in the example appends them one at a time;
        # each is the real stream_markdown action, and the last is the settled
        # turn's upsert.
        def ai_chat_message
          sleep 0.8 # long enough to see the question drawn before the server confirms it

          question = params.dig(:message, :content).to_s
          question_id = params.dig(:message, :client_id).presence || SecureRandom.uuid_v7
          reply_id = SecureRandom.uuid_v7
          browser_session[:ai_chat_reply] = reply_id

          render turbo_stream: [
            turbo_stream.action(:upsert, "demo_entries", helpers.ai_chat_message(question, role: :user, id: question_id)),
            turbo_stream.action(:upsert, "demo_entries", helpers.ai_chat_message(role: :assistant, id: reply_id, streaming: true)),
            turbo_stream.replace("demo_composer_action",
              helpers.ai_chat_composer_action(form: "demo_composer", state: :running, stop_form: "demo_stop")),
            turbo_stream.append("demo_driver", flushes(reply_id))
          ]
        end

        # Stop swaps in a settled note, which refuses the flushes still on their way.
        def ai_chat_stop
          reply_id = browser_session.delete(:ai_chat_reply)
          streams = [ turbo_stream.replace("demo_composer_action", helpers.ai_chat_composer_action(form: "demo_composer", state: :idle)) ]
          if reply_id
            stopped = helpers.streaming_markdown_tag(id: "#{reply_id}_content", final: true,
              class: "UnmagicAIChatMessage__body UnmagicProse") { helpers.tag.p("Response stopped.", class: "text-neutral-500") }
            streams << turbo_stream.replace("#{reply_id}_content", stopped)
          end

          render turbo_stream: streams
        end

        private

        def board_refresh(status = :ok)
          render turbo_stream: turbo_stream.refresh(request_id: nil), status: status
        end

        def flushes(reply_id)
          target = "#{reply_id}_content"
          frames = Reply.snapshots.map do |html|
            helpers.tag.template(turbo_stream.stream_markdown(target, html), data: { delay: rand(40..260), target: target })
          end

          settled = helpers.ai_chat_message(role: :assistant, id: reply_id) { Reply.html }
          idle = helpers.ai_chat_composer_action(form: "demo_composer", state: :idle, stop_form: "demo_stop")
          frames << helpers.tag.template(
            helpers.safe_join([ turbo_stream.action(:upsert, "demo_entries", settled), turbo_stream.replace("demo_composer_action", idle) ]),
            data: { delay: 400, target: target }
          )

          helpers.tag.template(helpers.safe_join(frames), data: { flushes: "" })
        end
      end
    end
  end
end
