# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unmagic::Components do
  describe ".with_default_configuration" do
    before do
      described_class.configure { |config| config.modal_frame_id = "host_modal" }
    end

    it "hands out the built-in seams inside the block, and the app's again after it" do
      inside = described_class.with_default_configuration { described_class.configuration.modal_frame_id }

      expect(inside).to eq("modal")
      expect(described_class.configuration.modal_frame_id).to eq("host_modal")
    end

    it "restores the app's configuration when the block raises" do
      expect { described_class.with_default_configuration { raise "boom" } }.to raise_error("boom")
      expect(described_class.configuration.modal_frame_id).to eq("host_modal")
    end

    # The browser's requests run alongside the app's own, which keep the app's seams.
    it "leaves other threads with the app's configuration" do
      seen = described_class.with_default_configuration do
        Thread.new { described_class.configuration.modal_frame_id }.value
      end

      expect(seen).to eq("host_modal")
    end

    it "configures the app, not the defaults, when configure runs inside the block" do
      described_class.with_default_configuration do
        described_class.configure { |config| config.modal_frame_id = "changed" }
      end

      expect(described_class.configuration.modal_frame_id).to eq("changed")
    end
  end
end
