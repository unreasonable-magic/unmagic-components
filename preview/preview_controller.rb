# frozen_string_literal: true

class PreviewController < ActionController::Base
  include Unmagic::Components::DialogResponder

  FLASH_TYPES = %w[notice alert warning info].freeze

  append_view_path File.expand_path("views", __dir__)

  # A frame request gets no layout, as turbo-rails arranges for an app's default
  # one; naming a layout here would otherwise override that. false, not nil: nil
  # falls back to layouts/preview by the controller's name.
  layout -> { turbo_frame_request? ? false : "preview" }

  def index
    @things = ComponentsPreview::Thing.all
  end

  def deferred
    @things = ComponentsPreview::Thing.all
  end

  def dialogs
    @profile = stored_profile
  end

  def edit_profile
    @profile = stored_profile
  end

  def update_profile
    @profile = ComponentsPreview::Profile.new(params.expect(profile: [ :name, :role ]))

    if @profile.valid?
      session[:profile] = @profile.attributes
      refresh_or_redirect "/dialogs", notice: "Profile saved."
    else
      render :edit_profile, status: :unprocessable_content
    end
  end

  def destroy_profile
    session.delete(:profile)
    redirect_to "/dialogs", status: :see_other, notice: "Profile reset."
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

  def primitives
  end

  def elements
    @now = Time.current
  end

  def skeletons
  end

  # A profile that has already failed validation, to show a field's invalid state.
  def forms
    @invalid_profile = ComponentsPreview::Profile.new(name: "", role: "Engineer").tap(&:validate)
  end

  def toasts
  end

  def flash_toast
    type = FLASH_TYPES.include?(params[:type]) ? params[:type] : "notice"
    flash[type] = params[:message]
    redirect_to "/toasts", status: :see_other
  end

  def stream_toast
    tone = Unmagic::Components::Toast::TONES.map(&:to_s).include?(params[:tone]) ? params[:tone].to_sym : :good
    render turbo_stream: turbo_stream.toast(params[:message], tone: tone)
  end

  private

  def stored_profile
    ComponentsPreview::Profile.new(session[:profile] || { name: "Ada Lovelace", role: "Engineer" })
  end
end
