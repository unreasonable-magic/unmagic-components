# frozen_string_literal: true

require "spec_helper"

# ActionView::TestCase is what a host's own helper specs run through, and it is not
# ActionView::Base — it builds its own view class and calls the helper under test on the test case
# itself. A host helper that composes one of ours has to find them there too.
require "action_view/test_case"

RSpec.describe "Engine helper mixin" do
  # The hook runs inside ActionView::TestCase::Behavior's `included` block, so it fires for the
  # class that includes the behaviour rather than once globally.
  it "mixes the helpers into ActionView::TestCase" do
    expect(ActionView::TestCase.include?(Unmagic::Components::ActionViewHelpers)).to be(true)
  end

  describe "a host's helper spec" do
    subject(:test_case) do
      Class.new(ActionView::TestCase) do
        def self.name = "HostHelperTest"
      end.new("example")
    end

    it "can call the helpers a host helper composes" do
      expect(test_case).to respond_to(:badge, :button_classes, :local_time_tag)
    end

    it "renders a badge rather than raising NoMethodError" do
      expect(html(test_case.badge("Draft", tone: :good)).at_css("span")["class"])
        .to eq("UnmagicBadge UnmagicBadge--good")
    end

    it "returns button classes" do
      expect(test_case.button_classes(:primary, size: :small))
        .to eq("UnmagicButton UnmagicButton--primary UnmagicButton--small")
    end
  end
end
