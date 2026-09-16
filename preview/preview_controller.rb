# frozen_string_literal: true

class PreviewController < ActionController::Base
  include Unmagic::Components::DialogResponder

  FLASH_TYPES = %w[notice alert warning info].freeze
  THEMES = %w[light dark].freeze

  append_view_path File.expand_path("views", __dir__)

  # A frame request gets no layout, as turbo-rails arranges for an app's default
  # one; naming a layout here would otherwise override that. false, not nil: nil
  # falls back to layouts/preview by the controller's name.
  layout -> { turbo_frame_request? ? false : "preview" }

  before_action :remember_theme, :load_catalog
  before_action :load_fixtures, only: %i[overview component]

  helper_method :dark_theme?, :example_source

  def overview
  end

  def installation
  end

  def theming
  end

  # One component's page: every example it lists, live and as source.
  def component
    @component = ComponentsPreview::Catalog.find(params[:slug])
    raise ActionController::RoutingError, "No component named #{params[:slug]}" unless @component
  end

  def edit_profile
    @profile = stored_profile
  end

  def update_profile
    @profile = ComponentsPreview::Profile.new(params.expect(profile: [ :name, :role ]))

    if @profile.valid?
      session[:profile] = @profile.attributes
      refresh_or_redirect "/components/dialog", notice: "Profile saved."
    else
      render :edit_profile, status: :unprocessable_content
    end
  end

  def destroy_profile
    session.delete(:profile)
    redirect_to "/components/confirm", status: :see_other, notice: "Profile reset."
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
    redirect_to "/components/toast", status: :see_other
  end

  def stream_toast
    tone = Unmagic::Components::Toast::TONES.map(&:to_s).include?(params[:tone]) ? params[:tone].to_sym : :good
    render turbo_stream: turbo_stream.toast(params[:message], tone: tone)
  end

  # The composer example's server: confirm the question under the id the form
  # minted, then hand the page a reply to play back as a model would stream it.
  # The preview has no Action Cable, so the flushes ride along in the response and
  # a small driver in the example appends them one at a time; each is the real
  # stream_markdown action, and the last is the settled turn's upsert.
  def ai_chat_message
    sleep 0.8 # long enough to see the question drawn before the server confirms it

    question = params.dig(:message, :content).to_s
    question_id = params.dig(:message, :client_id).presence || SecureRandom.uuid_v7
    reply_id = SecureRandom.uuid_v7
    session[:ai_chat_reply] = reply_id

    render turbo_stream: [
      turbo_stream.action(:upsert, "demo_entries", helpers.ai_chat_message(question, role: :user, id: question_id)),
      turbo_stream.action(:upsert, "demo_entries", helpers.ai_chat_message(role: :assistant, id: reply_id, streaming: true)),
      turbo_stream.replace("demo_composer_action", helpers.ai_chat_composer_action(form: "demo_composer", state: :running, stop_form: "demo_stop")),
      turbo_stream.append("demo_driver", flushes(reply_id))
    ]
  end

  # Stop swaps in a settled note, which refuses the flushes still on their way.
  def ai_chat_stop
    reply_id = session.delete(:ai_chat_reply)
    streams = [ turbo_stream.replace("demo_composer_action", helpers.ai_chat_composer_action(form: "demo_composer", state: :idle)) ]
    if reply_id
      stopped = helpers.streaming_markdown_tag(id: "#{reply_id}_content", final: true,
        class: "UnmagicAIChatMessage__body UnmagicProse") { helpers.tag.p("Response stopped.", class: "text-neutral-500") }
      streams << turbo_stream.replace("#{reply_id}_content", stopped)
    end

    render turbo_stream: streams
  end

  private

  def flushes(reply_id)
    target = "#{reply_id}_content"
    frames = ComponentsPreview::Reply.snapshots.map do |html|
      helpers.tag.template(turbo_stream.stream_markdown(target, html), data: { delay: rand(40..260), target: target })
    end

    settled = helpers.ai_chat_message(role: :assistant, id: reply_id) { ComponentsPreview::Reply.html }
    idle = helpers.ai_chat_composer_action(form: "demo_composer", state: :idle, stop_form: "demo_stop")
    frames << helpers.tag.template(
      helpers.safe_join([ turbo_stream.action(:upsert, "demo_entries", settled), turbo_stream.replace("demo_composer_action", idle) ]),
      data: { delay: 400, target: target }
    )

    helpers.tag.template(helpers.safe_join(frames), data: { flushes: "" })
  end

  # ?theme=dark or ?theme=light switches the preview and sticks for the session, so
  # links and redirects don't each have to carry it.
  def remember_theme
    session[:theme] = params[:theme] if THEMES.include?(params[:theme])
  end

  def dark_theme? = session[:theme] == "dark"

  def load_catalog
    ComponentsPreview::Catalog.reload!
    @components = ComponentsPreview::Catalog.all
    @component_groups = ComponentsPreview::Catalog.grouped
  end

  # The data examples and thumbnails render from, set for every page that shows
  # either, so any example can use any of it.
  def load_fixtures
    @things = ComponentsPreview::Thing.all
    @profile = stored_profile
    @invalid_profile = ComponentsPreview::Profile.new(name: "", role: "Engineer").tap(&:validate)
    @now = Time.current
  end

  # What the Code tab shows: the example's partial, exactly as it's rendered.
  def example_source(component, example)
    File.read(File.expand_path("views/examples/#{component.slug}/_#{example.key}.html.erb", __dir__)).rstrip
  end

  def stored_profile
    ComponentsPreview::Profile.new(session[:profile] || { name: "Ada Lovelace", role: "Engineer" })
  end
end
