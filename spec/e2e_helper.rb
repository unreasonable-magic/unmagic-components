# frozen_string_literal: true

require "puma"
require "puma/server"
require "unmagic/browser"

# End-to-end specs: the component browser, served by the spec application under
# its mount prefix, driven in a real Chrome through unmagic-browser. They cover
# what the Nokogiri specs can't see: custom elements, focus, computed styles.
#
#   bundle exec rspec spec/e2e            headless
#   HEADFUL=1 bundle exec rspec spec/e2e  in a window you can watch
#
# Chrome has to be installed; CHROME_PATH points at a particular binary.
module E2EHelpers
  MOUNT = "/unmagic/components"

  # What every script run by #js can call: settle lets mutation observers and
  # toggle events run, and repaint also waits out a Turbo Stream's render.
  PRELUDE = <<~JS
    const settle = () => new Promise(resolve => setTimeout(resolve, 20))
    const repaint = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))).then(settle)
  JS

  # A promise that never settles would hang the run, because an evaluation has
  # no timeout of its own. Race it, so a module that fails to load is a failure.
  DEADLINE = <<~JS
    (promise, what) => Promise.race([
      promise,
      new Promise((_, reject) => setTimeout(() => reject(new Error(`Timed out waiting for ${what}`)), 5000))
    ])
  JS

  class << self
    # Puma on a free local port, started on first use and kept for the run.
    def origin
      @origin ||= begin
        @server = Puma::Server.new(Rails.application, nil, log_writer: Puma::LogWriter.null)
        port = @server.add_tcp_listener("127.0.0.1", 0).addr[1]
        @server.run
        "http://127.0.0.1:#{port}"
      end
    end

    def base_url = "#{origin}#{MOUNT}"

    # One Chrome for the run: starting and stopping it costs more than most
    # examples do. #reset puts it back between them.
    def session
      @session ||= Unmagic::Browser.new(driver: Unmagic::Browser::Driver::Local.new(
        headless: ENV["HEADFUL"] != "1",
        executable_path: ENV["CHROME_PATH"],
        slow_mo: (30 if ENV["HEADFUL"] == "1")
      )).open
    end

    # Hands the next example a browser that remembers nothing: scripts on, the
    # default emulation (which also drops any raw media override), and no
    # cookies or storage, where the browser's theme would otherwise linger.
    def reset
      return unless @session

      page = @session.driver
      page.javascript_enabled = true
      @session.emulate
      page.client.send_message("Network.clearBrowserCookies")
      page.client.send_message("Storage.clearDataForOrigin", origin: origin, storageTypes: "all")
    end

    def stop
      @session&.close
      @server&.stop(true)
    end
  end

  def session = E2EHelpers.session

  # Visits a page of the component browser, e.g.
  # visit_browser("/components/ai_chat_tool_call"), and waits for the element
  # under test to be defined. The page's modules have run by its load event, so
  # there is no need to wait for the network to go quiet as Session#visit does.
  def visit_browser(path, defined: "unmagic-tool-call")
    session.driver.goto("#{E2EHelpers.base_url}#{path}", wait_until: "load")
    session.evaluate("name => (#{DEADLINE})(customElements.whenDefined(name).then(() => true), `<${name}> to be defined`)", defined) if defined
    session
  end

  # Runs the body of an async function in the page and returns what it returns,
  # so a spec acts in JavaScript and asserts in Ruby.
  def js(body)
    session.evaluate("() => (#{DEADLINE})((async () => {\n#{PRELUDE}\n#{body}\n})(), 'the script to finish')")
  end
end

RSpec.configure do |config|
  config.include E2EHelpers, :e2e
  config.define_derived_metadata(file_path: %r{/spec/e2e/}) { |metadata| metadata[:e2e] = true }

  config.after(:each, :e2e) { E2EHelpers.reset }
  config.after(:suite) { E2EHelpers.stop }
end
