# frozen_string_literal: true

require "open3"
require "tmpdir"
require "tailwindcss/ruby"

# The stylesheet is Tailwind source that the host's build compiles, so a mistyped
# @apply would only fail there, in someone's app. Compile it the way a host does
# and fail here first.
RSpec.describe "the Tailwind stylesheet" do
  let(:engine_css) { File.expand_path("../../../app/assets/tailwind/unmagic_components/engine.css", __dir__) }

  it "compiles inside a host's Tailwind build" do
    Dir.mktmpdir do |dir|
      input = File.join(dir, "application.css")
      output = File.join(dir, "tailwind.css")
      File.write(input, <<~CSS)
        @import "tailwindcss" source(none);
        @custom-variant dark (&:where(.dark, .dark *));
        @import "#{engine_css}";
      CSS

      _stdout, stderr, status = Open3.capture3(Tailwindcss::Ruby.executable, "-i", input, "-o", output)

      expect(status).to be_success, stderr
      css = File.read(output)
      expect(css).to include(".UnmagicInput", ".UnmagicCard", ".UnmagicMenu__panel", ".UnmagicTooltip__popup",
        ".UnmagicAvatar--tint-6", ".UnmagicProse", ".UnmagicAIChat", ".UnmagicAIChatToolCall__join", ".UnmagicAIChatPermission__allow",
        ".UnmagicBoard__cards", "[data-sortable-dragging]")
      expect(css).to include("@layer components")
    end
  end
end
