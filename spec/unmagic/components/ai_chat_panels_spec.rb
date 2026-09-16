# frozen_string_literal: true

RSpec.describe "AI chat plans, workspaces and failures" do
  let(:view) { build_view }

  describe "#ai_chat_plan" do
    it "renders an open checklist with each step's state" do
      plan = html(view.ai_chat_plan(id: "plan", class: "extra") do |p|
        p.step "Read the brief", state: :completed
        p.step "Draft the email", state: :in_progress
        p.step "Check the dates", state: :waiting
        p.step("Send it") { "To the whole team" }
      end).at("details#plan")

      expect(plan["class"]).to eq("UnmagicAIChatPlan extra")
      expect(plan.key?("open")).to be(true)
      expect(plan.at("summary h2.UnmagicAIChatPlan__title").text).to eq("Plan")
      expect(plan.at("summary .UnmagicAIChatPlan__count").text).to eq("1/4")

      steps = plan.css("ol.UnmagicAIChatPlan__steps > li")
      expect(steps.map { |step| step["data-state"] }).to eq(%w[completed in_progress waiting pending])
      expect(steps.map { |step| step.at(".UnmagicAIChatPlan__glyph .UnmagicVisuallyHidden").text })
        .to eq([ "Done", "In progress", "Waiting on you", "To do" ])
      expect(steps[1].at(".UnmagicAIChatSpinner")).not_to be_nil
      expect(steps[3].at(".UnmagicAIChatPlan__detail").text).to eq("To the whole team")
    end

    it "takes the reading it's given over the one it would count" do
      expect(html(view.ai_chat_plan(completed: 3, total: 9) { |p| p.step "x" }).at(".UnmagicAIChatPlan__count").text).to eq("3/9")
    end

    it "still renders, empty, for a broadcast to replace" do
      plan = html(view.ai_chat_plan(id: "plan")).at("#plan")
      expect(plan.at(".UnmagicAIChatPlan__empty").text).to eq("Nothing planned yet.")
      expect(plan.at(".UnmagicAIChatPlan__count")).to be_nil
      expect(html(view.ai_chat_plan(empty: "Nothing yet")).at(".UnmagicAIChatPlan__empty").text).to eq("Nothing yet")
    end

    it "can be a plain section with its own heading level" do
      plan = html(view.ai_chat_plan(collapsible: false, open: false, title: "Steps", title_tag: :h3)).at("section")
      expect(plan["class"]).to eq("UnmagicAIChatPlan UnmagicAIChatPlan--static")
      expect(plan.at("div.UnmagicAIChatPlan__head h3").text).to eq("Steps")
      expect(plan.at(".UnmagicAIChatChevron")).to be_nil
    end

    it "rejects an unknown step state" do
      expect { view.ai_chat_plan { |p| p.step "x", state: :blocked } }
        .to raise_error(ArgumentError, /unknown ai_chat_plan step state :blocked/)
    end
  end

  describe "#ai_chat_workspace" do
    it "lists files by path, linking only those with a url" do
      workspace = html(view.ai_chat_workspace(id: "workspace") do |w|
        w.file "captures/brief.png", size: 43_000, url: "/files/1"
        w.file "notes.md", icon: :pencil
      end).at("details#workspace")

      expect(workspace.at(".UnmagicAIChatWorkspace__count").text).to eq("2")
      first, second = workspace.css("ul.UnmagicAIChatWorkspace__files > li")
      expect(first["title"]).to eq("captures/brief.png")
      link = first.at("a.UnmagicAIChatWorkspace__link")
      expect(link["href"]).to eq("/files/1")
      expect(link.at(".UnmagicAIChatWorkspace__directory").text).to eq("captures/")
      expect(link.at(".UnmagicAIChatWorkspace__name").text).to eq("captures/brief.png")
      expect(link.at(".UnmagicAIChatWorkspace__size").text).to eq("42 KB")

      expect(second.at("a")).to be_nil
      expect(second.at(".UnmagicAIChatWorkspace__directory")).to be_nil
      expect(second.at("svg")["data-unmagic-icon"]).to end_with("/pencil")
    end

    it "still renders, empty" do
      workspace = html(view.ai_chat_workspace(id: "workspace", count: 0)).at("#workspace")
      expect(workspace.at(".UnmagicAIChatWorkspace__empty").text).to eq("No files yet.")
      expect(workspace.at(".UnmagicAIChatWorkspace__count").text).to eq("0")
    end
  end

  describe "#ai_chat_failure" do
    it "says what happened, folds away the diagnostics, and offers a retry" do
      failure = html(view.ai_chat_failure("The assistant couldn't finish this reply.", class: "extra") do |f|
        f.cause "Faraday::TimeoutError: execution expired"
        f.detail "Provider said", { "error" => "overloaded" }
        f.detail "Where it happened", "app/models/chat.rb:12", language: :plaintext
        f.retry "RETRY"
      end).at(".UnmagicAIChatFailure")

      expect(failure["class"]).to eq("UnmagicAIChatFailure extra")
      expect(failure["role"]).to be_nil
      expect(failure.at(".UnmagicAIChatFailure__message").text).to eq("The assistant couldn't finish this reply.")
      expect(failure.at(".UnmagicAIChatFailure__cause").text).to eq("Faraday::TimeoutError: execution expired")

      details = failure.at("details.UnmagicAIChatFailure__details")
      expect(details.key?("open")).to be(false)
      expect(details.at("summary").text).to eq("Details")
      expect(details.css(".UnmagicAIChatPayload__label").map(&:text)).to eq([ "Provider said", "Where it happened" ])
      expect(failure.at("> .UnmagicAIChatFailure__retry").text).to eq("RETRY")
    end

    it "is only the sentence when there is nothing else, and an alert when live" do
      failure = html(view.ai_chat_failure("It broke.", live: true)).at(".UnmagicAIChatFailure")
      expect(failure["role"]).to eq("alert")
      expect(failure.css("details, .UnmagicAIChatFailure__cause, .UnmagicAIChatFailure__retry")).to be_empty
    end
  end
end
