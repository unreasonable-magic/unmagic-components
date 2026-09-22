# frozen_string_literal: true

require "tmpdir"

# The browser written out as static files, under the prefix the spec app mounts
# it at, the way a GitHub Pages site would be.
RSpec.describe Unmagic::Components::Browser::Export do
  around do |example|
    Dir.mktmpdir { |dir| @dir = Pathname(dir); example.run }
  end

  let(:export) { described_class.new(app: Rails.application, mount: "/unmagic/components", dir: @dir) }

  it "writes every page, the modal's dialog, a 404 and the assets" do
    written = export.run

    expect(written).to include("index.html", "installation/index.html", "theming/index.html", "404.html",
      "components/card/index.html", "components/code_view/index.html", "dialogs/profile/index.html",
      "blocks/index.html", "blocks/workspace/index.html", "blocks/workspace/preview/index.html",
      "blocks/team/index.html", "blocks/team/preview/index.html",
      "blocks/login/preview/index.html", "blocks/signup/preview/index.html", "blocks/sidebar/preview/index.html",
      "assets/browser/browser.js",
      "assets/stylesheets/browser.css", "assets/javascripts/unmagic/components.js",
      "assets/javascripts/unmagic/components/tabs.js", "assets/turbo/turbo.min.js")
    expect(written.grep(%r{\Acomponents/}).size).to eq(Unmagic::Components::Browser::Catalog.all.size)
    expect(@dir.join("components/card/index.html")).to exist
  end

  it "keeps links and asset URLs under the mount, and the modal's frame in its dialog" do
    export.run

    page = File.read(@dir.join("components/card/index.html"))
    expect(page).to include('href="/unmagic/components/components/badge"')
    expect(page).to include('href="/unmagic/components/assets/stylesheets/browser.css?v=')
    expect(page).to include('"unmagic/components/tabs":"/unmagic/components/assets/javascripts/unmagic/components/tabs.js?v=')

    dialog = File.read(@dir.join("dialogs/profile/index.html"))
    expect(dialog).to include('<turbo-frame id="modal">')
    expect(dialog).not_to include("<html")
  end

  it "says which examples need a server, only on the static pages" do
    export.run

    expect(File.read(@dir.join("components/dialog/index.html"))).to include("This example talks to a server")
    expect(File.read(@dir.join("components/card/index.html"))).not_to include("This example talks to a server")
    expect(Unmagic::Components::Browser.static?).to be(false)

    live = Rack::MockRequest.new(Rails.application).get("/unmagic/components/components/dialog", "HTTP_HOST" => "localhost")
    expect(live.body).not_to include("This example talks to a server")
  end

  it "carries the theme script and a toggle the script points" do
    export.run

    page = File.read(@dir.join("index.html"))
    expect(page).to include("unmagic-components-browser-theme")
    expect(page).to include("data-theme-toggle")
  end
end
