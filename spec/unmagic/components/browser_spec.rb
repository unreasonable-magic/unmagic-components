# frozen_string_literal: true

require "spec_helper"
require "digest"
require "open3"
require "tmpdir"
require "tailwindcss/ruby"

# The browser a host mounts. spec_helper mounts it at /unmagic/components, so
# every path here has to carry that prefix.
RSpec.describe Unmagic::Components::Browser do
  let(:prefix) { "/unmagic/components" }
  let(:app) { Rack::MockRequest.new(Rails.application) }

  def get(path) = app.get("http://localhost#{prefix}#{path}")
  def page(path) = Nokogiri::HTML5(get(path).body)

  describe "pages" do
    it "renders the overview, the getting-started pages and the component gallery" do
      %w[/ /installation /theming /components].each do |path|
        expect(get(path).status).to eq(200), "#{path} answered #{get(path).status}"
      end
    end

    it "renders every component in the catalog" do
      slugs = described_class::Catalog.all.map(&:slug)
      expect(slugs).to include("table", "dialog", "board", "ai_chat")

      slugs.each do |slug|
        response = get("/components/#{slug}")
        expect(response.status).to eq(200), "#{slug} answered #{response.status}: #{response.body[0, 500]}"
      end
    end

    # A duplicate breaks whatever looks the id up: Turbo sends a modal link to the
    # first element with the frame's id, and a label to the first field. What sits
    # in a <template> isn't in the document yet.
    it "gives no two elements on a component's page the same id" do
      repeated = described_class::Catalog.all.to_h do |component|
        live = page("/components/#{component.slug}").css("[id]").reject { |node| node.ancestors("template").any? }
        ids = live.map { |node| node["id"] }
        [ component.slug, ids.tally.select { |_, count| count > 1 }.keys ]
      end

      expect(repeated.reject { |_, ids| ids.empty? }).to eq({})
    end

    it "answers 404 for a component it doesn't have" do
      expect(get("/components/nope").status).to eq(404)
    end

    it "shows the toast's captured slots in its source tab" do
      source = page("/components/toast").at_css("#toast_content_source").text
      expect(source).to include("toast.actions", "turbo_stream.toast", "unmagic_toast_dismiss")
    end

    it "shows an example's source beside it" do
      source = page("/components/dialog").at_css("#dialog_modal_source").text
      expect(source).to include("modal_link_to \"Edit profile\", profile_dialog_path")
    end
  end

  describe "blocks" do
    it "gives every catalog component a home in a block" do
      expect(described_class::BlockCatalog.uncovered_components.map(&:slug)).to eq([])
      declared = described_class::BlockCatalog.all.flat_map(&:components).uniq
      expect(declared).to match_array(described_class::Catalog.all.map(&:slug))
    end

    it "links components back to the blocks that use them" do
      html = page("/components/image_crop")
      expect(html.at_css('nav[aria-label="Used in blocks"] a')["href"]).to eq("#{prefix}/blocks/asset_studio")
    end

    it "renders local contact pages that work without a server" do
      html = page("/blocks/customer_workspace/preview")
      expect(html.at_css("#contacts_page_1").text).to include("Ada Lovelace")
      expect(html.at_css("#contacts_page_1")["hidden"]).to be_nil
      expect(html.at_css("#contacts_page_2").text).to include("Radia Perlman")
      expect(html.at_css("#contacts_page_2")["hidden"]).not_to be_nil
      expect(html.css("#customer_contacts nav a").map { |node| node["href"] }).to all(start_with("#contacts_page_"))
    end

    it "keeps global navigation separate from section navigation" do
      html = page("/blocks")
      expect(html.at_css('nav[aria-label="Global"] [aria-current="page"]').text).to eq("Blocks")
      expect(html.css('nav[data-browser-nav] a').map(&:text)).to include("All blocks", "Workspace overview", "Team directory")
      expect(html.css('nav[data-browser-nav] a').map(&:text)).not_to include("Installation")
      expect(page("/components/card").at_css('nav[aria-label="Global"] [aria-current="page"]').text).to eq("Components")
    end

    it "shows the component gallery and only components in the Components section" do
      html = page("/components")
      expect(html.at_css('nav[aria-label="Global"] [aria-current="page"]').text).to eq("Components")
      expect(html.at_css("a[href='#{prefix}/components/card']")).not_to be_nil
      links = html.css('nav[aria-label="Components"] a').map { |link| link.text.strip }
      expect(links).to include("All components", "Card")
      expect(links).not_to include("Overview", "Installation", "Theming")
      expect(page("/installation").at_css('nav[aria-label="Global"] [aria-current="page"]').text).to eq("Guides")
    end

    it "renders each block, its source and an isolated preview under the mount" do
      described_class::BlockCatalog.all.each do |block|
        response = get("/blocks/#{block.slug}")
        expect(response.status).to eq(200)
        html = Nokogiri::HTML5(response.body)
        expect(html.at_css("iframe")["src"]).to eq("#{prefix}/blocks/#{block.slug}/preview?preview_theme=light")
        expect(html.at_css("#block_#{block.slug}_source").text).to include("<%=")
        preview = page("/blocks/#{block.slug}/preview")
        expect(get("/blocks/#{block.slug}/preview").status).to eq(200)
        expect(preview.at_css('nav[aria-label="Global"]')).to be_nil
        expect(preview.at_css("main")).not_to be_nil
        ids = preview.css("[id]").reject { |node| node.ancestors("template").any? }.map { |node| node["id"] }
        expect(ids.uniq).to eq(ids)
      end
    end

    it "offers independent viewport and theme controls" do
      html = page("/blocks/login")
      expect(html.css("[data-preview-width]").map { |node| node["aria-label"] }).to eq(%w[Desktop Tablet Phone])
      expect(html.css("[data-preview-theme]").map { |node| node["data-preview-theme"] }).to eq(%w[light dark])
      expect(html.at_css("[data-preview-reload]")).not_to be_nil
      expect(page("/blocks/login/preview").at_css("form")["method"]).to eq("dialog")
    end

    it "rejects unknown blocks and preview names" do
      expect(get("/blocks/nope").status).to eq(404)
      expect(get("/blocks/nope/preview").status).to eq(404)
    end
  end

  describe "guides" do
    it "lists every guide and renders each, with its sections and links to its components" do
      index = page("/")
      expect(index.css('nav[aria-label="Global"] a').map(&:text)).to eq(%w[Guides Components Blocks])
      expect(index.at_css('nav[aria-label="Global"] [aria-current="page"]').text).to eq("Guides")
      expect(index.css('nav[aria-label="Guides"] a').map(&:text)).to include("Overview", "Installation", "Theming", "Turbo Stream actions")
      expect(index.css('nav[aria-label="Guides"] a').map(&:text)).not_to include("All guides", "Card")

      described_class::GuideCatalog.all.each do |guide|
        expect(index.at_css("a[href='#{prefix}/guides/#{guide.slug}']")).not_to be_nil
        response = get("/guides/#{guide.slug}")
        expect(response.status).to eq(200), "#{guide.slug} answered #{response.status}: #{response.body[0, 500]}"
        html = Nokogiri::HTML5(response.body)
        expect(html.at_css("h1").text).to eq(guide.name)
        expect(html.at_css('nav[aria-label="Guides"] [aria-current="page"]').text).to eq(guide.name)
        expect(html.css("article h2")).not_to be_empty
        guide.components.each do |slug|
          expect(described_class::Catalog.find(slug)).not_to be_nil, "#{guide.slug} links to a missing #{slug}"
          expect(html.at_css("a[href='#{prefix}/components/#{slug}']")).not_to be_nil
        end
        ids = html.css("[id]").reject { |node| node.ancestors("template").any? }.map { |node| node["id"] }
        expect(ids.uniq).to eq(ids)
      end
    end

    it "shows ERB in a guide's code as written" do
      source = page("/guides/modal_forms").at_css("#modal_dialog_code").text
      expect(source).to include(%(<%= dialog title: "Edit label", form: { model: @label } do |dialog, form| %>))
    end

    it "answers 404 for a guide it doesn't have" do
      expect(get("/guides/nope").status).to eq(404)
    end
  end

  describe "under a mount prefix" do
    it "keeps the prefix on links and forms" do
      html = page("/components/dialog")
      paths = html.css("a[href^='/'], form[action^='/']").map { |node| node["href"] || node["action"] }

      expect(paths).not_to be_empty
      expect(paths).to all(start_with(prefix))
      expect(paths).to include("#{prefix}/", "#{prefix}/components/toast", "#{prefix}/dialogs/profile")
    end

    it "keeps the prefix when an old URL redirects" do
      expect(get("/dialogs").headers["location"]).to end_with("#{prefix}/components/dialog")
    end

    it "renders all toast stream examples" do
      %w[content actions leading custom image upload boundaries javascript_rails].each do |example|
        response = app.post("http://localhost#{prefix}/toasts/stream",
          params: { example: example, message: "Example", tone: "neutral" })
        expect(response.status).to eq(200), "#{example}: #{response.body[0, 500]}"
        expect(response.body).to include("data-unmagic-toast-template")
        expect(response.body).to include('target="toast_panel"') if example == "boundaries"
      end
    end

    it "keeps the prefix when a demo redirects" do
      response = app.post("http://localhost#{prefix}/toasts/flash", params: { type: "alert", message: "Nope." })

      expect(response.status).to eq(303)
      expect(response.headers["location"]).to end_with("#{prefix}/components/toast")
    end
  end

  describe "its own CSS and JavaScript" do
    let(:head) { page("/").at_css("head") }
    let(:imports) { JSON.parse(head.at_css("script[type=importmap]").text).fetch("imports") }

    it "links the prebuilt stylesheet, and serves it" do
      href = head.at_css("link[rel=stylesheet]")["href"]
      expect(href).to start_with("#{prefix}/assets/stylesheets/browser.css?v=#{Unmagic::Components::VERSION}-")

      response = app.get("http://localhost#{href}")
      expect(response.status).to eq(200)
      expect(response.headers["content-type"]).to start_with("text/css")
      expect(response.body).to include(".UnmagicCard", ".PreviewExample")
    end

    it "maps every name a host's importmap pins, and imports the components" do
      pinned = []
      recorder = Object.new
      recorder.define_singleton_method(:pin) { |name, **| pinned << name }
      recorder.define_singleton_method(:pin_all_from) do |dir, under:, **|
        Dir[File.join(dir, "**/*.js")].each { |file| pinned << "#{under}/#{file.delete_prefix("#{dir}/").delete_suffix(".js")}" }
      end
      importmap = File.expand_path("../../../config/importmap.rb", __dir__)
      recorder.instance_eval(File.read(importmap), importmap)

      expect(pinned).to include("unmagic/components", "unmagic/components/modal")
      expect(imports.keys).to match_array(pinned + [ "@hotwired/turbo-rails" ])
      expect(head.css("script[type=module]").map(&:text)).to include('import "unmagic/components"')
    end

    it "stamps Turbo with turbo-rails' version, which changes when it's upgraded" do
      expect(imports["@hotwired/turbo-rails"]).to include("?v=#{Gem.loaded_specs["turbo-rails"].version}-")
    end

    it "serves the modules and Turbo the importmap points at" do
      imports.values_at("unmagic/components", "unmagic/components/modal", "@hotwired/turbo-rails").each do |url|
        response = app.get("http://localhost#{url}")
        expect(response.status).to eq(200), "#{url} answered #{response.status}"
        expect(response.headers["content-type"]).to match(%r{\A(text|application)/javascript})
      end
    end

    it "serves nothing outside its asset directories" do
      expect(app.get("http://localhost#{prefix}/assets/javascripts/../../../../Gemfile").status).to eq(404)
    end

    it "carries the stylesheet a fresh build would write" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "browser.css")
        _stdout, stderr, status = Open3.capture3(Tailwindcss::Ruby.executable, "--minify",
          "-i", described_class.root.join("tailwind/browser.css").to_s, "-o", output)

        expect(status).to be_success, stderr
        fresh = Digest::SHA256.file(output).hexdigest
        expect(Digest::SHA256.file(described_class.root.join("assets/browser.css")).hexdigest).to eq(fresh),
          "assets/browser.css is stale: run `bundle exec rake browser:css` and commit it"
      end
    end
  end

  # A host's seams render the host's partials, which call the host's helpers,
  # which the browser's controller doesn't have. So none of them runs in here.
  it "renders with the built-in seams, whatever the host configured" do
    Unmagic::Components.configure do |config|
      config.empty_state = ->(*) { raise "the host's empty_state ran" }
      config.pagination = ->(*, **) { raise "the host's pagination ran" }
      config.submit_class = ->(*) { raise "the host's submit_class ran" }
      config.control_class = ->(*) { raise "the host's control_class ran" }
    end

    described_class::Catalog.all.each do |component|
      response = get("/components/#{component.slug}")
      expect(response.status).to eq(200), "#{component.slug} answered #{response.status}: #{response.body[0, 500]}"
    end
    expect(page("/components/table").at_css(".UnmagicEmptyState")).not_to be_nil
    expect { Unmagic::Components.configuration.empty_state.call }.to raise_error(/host's empty_state/)
  end

  # Likewise a host's default form builder, which a form_with with no builder:
  # would otherwise pick up.
  it "renders with Rails' form builder, whatever the host's default is" do
    host_builder = Class.new(ActionView::Helpers::FormBuilder) do
      def text_field(*) = raise("the host's form builder ran")
    end
    original = ActionView::Base.default_form_builder
    ActionView::Base.default_form_builder = host_builder

    described_class::Catalog.all.each do |component|
      response = get("/components/#{component.slug}")
      expect(response.status).to eq(200), "#{component.slug} answered #{response.status}: #{response.body[0, 500]}"
    end
  ensure
    ActionView::Base.default_form_builder = original
  end

  it "says what's missing when turbo-rails isn't in the bundle" do
    hide_const("Turbo::Engine")
    controller = described_class::ApplicationController.new

    expect { controller.send(:require_turbo) }.to raise_error(RuntimeError, /needs turbo-rails/)
  end
end
