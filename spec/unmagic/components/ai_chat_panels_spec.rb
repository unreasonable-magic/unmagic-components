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
    def icon_of(row) = row.at("svg.UnmagicTree__icon")["data-unmagic-icon"].split("/").last

    it "groups files into open folders of a tree, linking only those with a url" do
      workspace = html(view.ai_chat_workspace(id: "workspace", class: "extra") do |w|
        w.file "captures/brief.png", size: 43_000, url: "/files/1"
        w.file "notes.md", icon: :pencil
        w.file "captures/moodboard.jpg"
      end).at("details#workspace")

      expect(workspace["class"]).to eq("UnmagicAIChatWorkspace extra")
      expect(workspace.at(".UnmagicAIChatWorkspace__count").text).to eq("3")

      tree = workspace.at("ul.UnmagicTree.UnmagicAIChatWorkspace__files")
      expect(tree["aria-label"]).to eq("Workspace")
      folder, notes = tree.css("> li")

      captures = folder.at("> details.UnmagicTree__branch")
      expect(captures["open"]).not_to be_nil
      summary = captures.at("> summary.UnmagicAIChatWorkspace__folder")
      expect([ summary.text, summary["title"], icon_of(summary) ]).to eq(%w[captures captures folder])

      brief, moodboard = captures.css("> ul.UnmagicTree__children > li > .UnmagicAIChatWorkspace__file")
      expect(brief.name).to eq("a")
      expect(brief["href"]).to eq("/files/1")
      expect(brief["title"]).to eq("captures/brief.png")
      expect(brief.at(".UnmagicTree__label").text).to eq("brief.png")
      expect(brief.at(".UnmagicTree__meta").text).to eq("42 KB")
      expect(moodboard.name).to eq("span")
      expect(moodboard.at(".UnmagicTree__meta")).to be_nil

      row = notes.at("> .UnmagicAIChatWorkspace__file")
      expect([ row.name, row.text, icon_of(row) ]).to eq(%w[span notes.md pencil])
    end

    it "nests folders, puts them before the files beside them, and joins a folder that only holds a folder" do
      tree = html(view.ai_chat_workspace do |w|
        w.file "summary.md"
        w.file "captures/careers.example-international.com/jobs/senior-engineer.html"
        w.file "captures/careers.example-international.com/jobs/staff-engineer.html"
        w.file "captures/index.html"
        w.file "/scratch/./data/rows.csv"
      end).at("ul.UnmagicTree")

      rows = tree.css("summary, .UnmagicTree__row--leaf").map do |row|
        [ row.ancestors("ul.UnmagicTree__children").size, row.at(".UnmagicTree__label").text, row["title"] ]
      end
      expect(rows).to eq([
        [ 0, "captures", "captures" ],
        [ 1, "careers.example-international.com/jobs", "captures/careers.example-international.com/jobs" ],
        [ 2, "senior-engineer.html", "captures/careers.example-international.com/jobs/senior-engineer.html" ],
        [ 2, "staff-engineer.html", "captures/careers.example-international.com/jobs/staff-engineer.html" ],
        [ 1, "index.html", "captures/index.html" ],
        [ 0, "scratch/data", "scratch/data" ],
        [ 1, "rows.csv", "/scratch/./data/rows.csv" ],
        [ 0, "summary.md", "summary.md" ]
      ])

      joined = tree.css("summary")[1].at(".UnmagicAIChatWorkspace__path")
      expect(joined.at(".UnmagicAIChatWorkspace__directory").text).to eq("careers.example-international.com")
      expect(joined.at(".UnmagicAIChatWorkspace__name").text).to eq("/jobs")
      expect(tree.css("details").map { |details| details.key?("open") }.uniq).to eq([ true ])
    end

    it "picks a file's icon from its extension, falling back to a plain file" do
      tree = html(view.ai_chat_workspace do |w|
        %w[page.html notes.md brief.PNG scene.json rows.csv bundle.tar.gz take.mp3 clip.mov Makefile .env].each do |path|
          w.file path
        end
        w.file "unknown.xyz", icon: :image
      end).at("ul.UnmagicTree")

      expect(tree.css(".UnmagicAIChatWorkspace__file").map { |row| icon_of(row) }).to eq(%w[
        file-code file-text file-image file-json file-spreadsheet file-archive file-audio file-video file file image
      ])
      expect(Unmagic::Components::AIChat::Workspace.icon_for("app/models/user.rb")).to eq(:file_code)
      expect(Unmagic::Components::AIChat::Workspace.icon_for("README")).to eq(:file)
      expect(Unmagic::Components::AIChat::Workspace::FILE_ICONS.values.uniq - Unmagic::Components::Icons.names).to eq([])
    end

    it "counts files, not folders, unless count: says otherwise" do
      workspace = html(view.ai_chat_workspace(count: 12) do |w|
        w.file "a/b/one.txt"
        w.file "a/two.txt"
      end)

      expect(workspace.at(".UnmagicAIChatWorkspace__count").text).to eq("12")
      expect(html(view.ai_chat_workspace { |w| w.file "a/b/one.txt" }).at(".UnmagicAIChatWorkspace__count").text).to eq("1")
    end

    it "still renders, empty" do
      workspace = html(view.ai_chat_workspace(id: "workspace", count: 0)).at("#workspace")
      expect(workspace.at(".UnmagicAIChatWorkspace__empty").text).to eq("No files yet.")
      expect(workspace.at(".UnmagicAIChatWorkspace__count").text).to eq("0")
    end
  end

  # ai_chat.js carries a reader's open or shut across a broadcast by this mark;
  # the script itself is checked by hand on the plan's browser page.
  describe "disclosures a broadcast replaces" do
    it "marks a plan and a workspace with their id, so a reader's choice outlasts a replace" do
      expect(html(view.ai_chat_plan(id: "plan")).at("details#plan")["data-ai-chat-disclosure"]).to eq("plan")
      expect(html(view.ai_chat_plan(id: "plan", open: false)).at("details#plan")["open"]).to be_nil
      expect(html(view.ai_chat_workspace(id: "files")).at("details#files")["data-ai-chat-disclosure"]).to eq("files")
    end

    it "marks a tool call's details and reasoning with the id they were given" do
      call = html(view.ai_chat_tool_call(name: "search", state: :running, id: "call_1") { |tool| tool.asked "car seat" })
      expect(call.at("#call_1 details")["data-ai-chat-disclosure"]).to eq("call_1")

      reasoning = html(view.ai_chat_reasoning(id: "thinking_1", streaming: true) { "Considering…" })
      expect(reasoning.at("details")["data-ai-chat-disclosure"]).to eq("thinking_1")
    end

    it "leaves one without an id, or one that doesn't collapse, unmarked" do
      expect(html(view.ai_chat_plan).at("details")["data-ai-chat-disclosure"]).to be_nil
      expect(html(view.ai_chat_plan(id: "plan", collapsible: false)).at("[data-ai-chat-disclosure]")).to be_nil
      call = html(view.ai_chat_tool_call(name: "search", state: :done) { |tool| tool.asked "x" })
      expect(call.at("details")["data-ai-chat-disclosure"]).to be_nil
      expect(html(view.ai_chat_reasoning { "x" }).at("details")["data-ai-chat-disclosure"]).to be_nil
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
