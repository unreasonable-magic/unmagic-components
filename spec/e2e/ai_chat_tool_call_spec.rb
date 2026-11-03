# frozen_string_literal: true

require "e2e_helper"

RSpec.describe "ai_chat_tool_call in a browser" do
  states = %w[queued running waiting done failed]

  # A payload as the server or a stream would write it.
  payload = <<~HTML.strip
    <figure><figcaption>Answered</figcaption><div role="region" tabindex="0" aria-label="Answered"><pre>config/database.yml</pre></div></figure>
  HTML

  describe "on the component's page" do
    before { visit_browser("/components/ai_chat_tool_call") }

    it "leaves the markup as the server wrote it, adding only the glyph" do
      expect(js(<<~JS)).to eq("legacy" => false, "children" => %w[DETAILS DIV], "fold" => %w[SUMMARY FIGURE], "glyphs" => 1)
        const call = document.querySelector("#written_helper")
        return {
          legacy: !!document.querySelector('[class*="UnmagicAIChatToolCall"], [data-part]'),
          children: [ ...call.children ].map(node => node.tagName),
          fold: [ ...call.querySelector(":scope > details").children ].map(node => node.tagName),
          glyphs: call.querySelectorAll("[data-tool-call-glyph]").length
        }
      JS
    end

    it "keeps an empty fold out of the way, and lets it in once a payload lands" do
      expect(js(<<~JS)).to eq("before" => { "chevron" => "none", "tab" => "-1", "pointer" => "none" }, "after" => { "chevron" => "block", "tab" => nil, "pointer" => "auto" })
        const call = document.querySelector("#written_direct")
        const details = call.querySelector(":scope > details")
        const summary = details.querySelector("summary")
        const read = () => ({
          chevron: getComputedStyle(summary, "::after").display,
          tab: summary.getAttribute("tabindex"),
          pointer: getComputedStyle(summary).pointerEvents
        })
        const before = read()
        details.insertAdjacentHTML("beforeend", #{payload.to_json})
        await repaint()
        return { before, after: read() }
      JS
    end

    it "streams a payload, progress and a result to where they belong, and a state change leaves them alone" do
      expect(js(<<~JS)).to eq("fold" => %w[SUMMARY FIGURE], "progress" => "Frame 13 of 40", "result" => "Open", "state" => "done", "same" => true, "busy" => false)
        const call = document.querySelector("#written_direct")
        const stream = (action, attributes, html = "") => {
          const element = document.createElement("turbo-stream")
          element.setAttribute("action", action)
          for (const [ name, value ] of Object.entries(attributes)) element.setAttribute(name, value)
          element.innerHTML = `<template>${html}</template>`
          document.body.append(element)
        }
        stream("append", { targets: "#written_direct > details" }, #{payload.to_json})
        stream("update", { targets: "#written_direct > details > summary > output" }, "Frame 13 of 40")
        stream("append", { target: "written_direct" }, "<div><a href='#'>Open</a></div>")
        await repaint()
        const figure = call.querySelector("figure")
        stream("tool_call_state", { targets: "#written_direct", state: "done" })
        await repaint()
        return {
          fold: [ ...call.querySelector(":scope > details").children ].map(node => node.tagName),
          progress: call.querySelector("output").textContent,
          result: call.lastElementChild.textContent,
          state: call.state,
          same: call.querySelector("figure") === figure,
          busy: call.hasAttribute("aria-busy")
        }
      JS
    end

    it "colours the glyph by state and the name by failure, in the helper's and the hand-written call alike" do
      seen = js(<<~JS)
        const colour = node => getComputedStyle(node).color
        const direct = document.querySelector("#written_direct")
        const folded = Object.fromEntries(#{states.to_json}.map(state => {
          const call = document.querySelector(`#state_${state}`)
          return [ state, { glyph: colour(call.querySelector("[data-tool-call-glyph]")), name: colour(call.querySelector("summary > code")) } ]
        }))
        direct.state = "failed"
        await repaint()
        return { folded, direct: { glyph: colour(direct.querySelector("[data-tool-call-glyph]")), name: colour(direct.querySelector("summary > code")) } }
      JS

      folded = seen["folded"]
      expect(folded["failed"]).to eq(seen["direct"])
      expect(folded["failed"]["glyph"]).to eq(folded["failed"]["name"])
      expect([ folded["waiting"]["glyph"], folded["failed"]["glyph"], folded["done"]["glyph"], folded["running"]["glyph"] ].uniq.size).to eq(4)
      expect(folded["queued"]["glyph"]).to eq(folded["done"]["glyph"])
      expect(folded.except("failed").values.map { |call| call["name"] }.uniq).to eq([ folded["running"]["name"] ])
    end

    it "shows each state's readings from CSS alone: the clock over the duration while running, the count until failed" do
      shown = js(<<~JS)
        const visible = node => node && getComputedStyle(node).display !== "none"
        return Object.fromEntries(#{states.to_json}.map(state => {
          const summary = document.querySelector(`#state_${state} summary`)
          return [ state, {
            busy: summary.closest("unmagic-tool-call").getAttribute("aria-busy") === "true",
            progress: visible(summary.querySelector("output")),
            clock: visible(summary.querySelector("unmagic-elapsed")),
            duration: visible(summary.querySelector("time")),
            failures: visible(summary.querySelector("data")),
            hidden: [ ...summary.querySelectorAll("[hidden]") ].length
          } ]
        }))
      JS

      expect(shown).to eq(states.to_h { |state|
        [ state, { "busy" => state == "running", "progress" => state == "running", "clock" => state == "running",
                   "duration" => state != "running", "failures" => state != "failed", "hidden" => 0 } ]
      })
    end

    it "orders the progress line after the chevron, so the chevron can't wrap below it" do
      expect(js('return getComputedStyle(document.querySelector("#state_running summary > output")).order')).to eq("1")
    end

    it "remembers the reader's choice for a call with an id through a replacement and a morph" do
      expect(js(<<~JS)).to eq("replaced" => true, "morphed" => true, "unkeyed" => false)
        const call = document.querySelector("#state_done")
        const summary = call.querySelector("summary")
        summary.click()
        await settle()
        const open = call.querySelector("details").open
        const replacement = call.cloneNode(true)
        replacement.querySelector("details").open = !open
        call.replaceWith(replacement)
        await repaint()
        const replaced = replacement.querySelector("details").open === open
        const morphed = await new Promise(resolve => {
          const details = replacement.querySelector("details")
          const event = new CustomEvent("turbo:before-morph-attribute", { bubbles: true, cancelable: true, detail: { attributeName: "open" } })
          details.dispatchEvent(event)
          resolve(event.defaultPrevented)
        })
        const plain = document.querySelector("#state_waiting")
        plain.removeAttribute("id")
        plain.querySelector("summary").click()
        await settle()
        const unkeyedOpen = plain.querySelector("details").open
        const again = plain.cloneNode(true)
        again.querySelector("details").open = !unkeyedOpen
        plain.replaceWith(again)
        await repaint()
        return { replaced, morphed, unkeyed: again.querySelector("details").open === unkeyedOpen }
      JS
    end

    it "moves through every state by property and by attribute, relabels from a label attribute, and reflects the name" do
      expect(js(<<~JS)).to eq("states" => states, "label" => "En cours", "invalid" => "TypeError", "unknown" => "queued", "name" => %w[updated updated])
        const call = document.querySelector("#written_direct")
        const seen = []
        for (const state of #{states.to_json}) {
          if (seen.length % 2) call.setAttribute("state", state)
          else call.state = state
          await settle()
          seen.push(call.querySelector("[data-tool-call-glyph]").dataset.toolCallGlyph)
        }
        call.setAttribute("label-running", "En cours")
        call.state = "running"
        await settle()
        const label = call.querySelector("[data-tool-call-glyph] .UnmagicVisuallyHidden").textContent
        let invalid
        try { call.state = "lost" } catch (error) { invalid = error.constructor.name }
        call.setAttribute("state", "lost")
        await settle()
        const unknown = call.state
        call.name = "updated"
        await settle()
        return { states: seen, label, invalid, unknown, name: [ call.getAttribute("name"), call.querySelector("summary > code").textContent ] }
      JS
    end

    it "gives a hand-written call a name and a glyph, and a clone keeps one of each" do
      expect(js(<<~JS)).to eq("order" => %w[SPAN CODE SPAN OUTPUT], "clone" => [ 1, 1 ])
        const call = document.querySelector("#written_direct")
        const order = [ ...call.querySelector("summary").children ].map(node => node.tagName)
        const clone = document.querySelector("#state_done").cloneNode(true)
        clone.id = "element_state_clone"
        document.querySelector("#state_done").after(clone)
        await settle()
        return { order, clone: [ clone.querySelectorAll("[data-tool-call-glyph]").length, clone.querySelectorAll("summary > code").length ] }
      JS
    end
  end

  # Every place the browser renders a tool call, reached by a Turbo visit as a
  # reader would, at both ends of the layouts and themes.
  describe "in each consumer" do
    renderings = {
      "on a desktop in light" => { theme: "light", viewport: { width: 1280, height: 900 } },
      "on a phone in dark" => { theme: "dark", viewport: { width: 390, height: 844, scale: 2, mobile: true, touch: true } }
    }
    consumers = {
      "the tool call page" => "/components/ai_chat_tool_call",
      "the conversation" => "/components/ai_chat",
      "the assistant workspace" => "/blocks/assistant_workspace/preview"
    }

    renderings.each do |rendering, emulation|
      consumers.each do |consumer, path|
        it "upgrades #{consumer} #{rendering}, and opens a fold from the keyboard there" do
          session.emulate(viewport: emulation[:viewport], color_scheme: emulation[:theme].to_sym) do
            visit_browser("/components/ai_chat_tool_call?theme=#{emulation[:theme]}")
            url = "#{E2EHelpers.base_url}#{path}?theme=#{emulation[:theme]}"

            page = js(<<~JS)
              if (!location.pathname.endsWith(#{path.to_json})) {
                await new Promise(resolve => {
                  document.addEventListener("turbo:load", resolve, { once: true })
                  Turbo.visit(#{url.to_json})
                })
                await repaint()
              }
              const calls = [ ...document.querySelectorAll("unmagic-tool-call") ]
              const call = calls.find(node => node.querySelector(":scope > details > figure"))
              const details = call.querySelector("details")
              call.scrollIntoView({ block: "center" })
              details.open = false
              details.querySelector("summary").focus()
              window.e2eCall = call
              return {
                path: location.pathname,
                theme: document.documentElement.dataset.theme,
                calls: calls.length,
                upgraded: calls.every(node => node.querySelector("[data-tool-call-glyph]")),
                native: calls.every(node => node.firstElementChild.tagName === "DETAILS" && !node.querySelector("[class*='UnmagicAIChatToolCall'], [data-part]"))
              }
            JS

            expect(page).to include("path" => "#{E2EHelpers::MOUNT}#{path}", "theme" => emulation[:theme], "upgraded" => true, "native" => true)
            expect(page["calls"]).to be > 0

            session.press(:enter)
            expect(js("return window.e2eCall.querySelector('details').open")).to be(true)
          end
        end
      end
    end
  end

  describe "under reduced motion and forced colours" do
    before do
      session.driver.client.send_message("Emulation.setEmulatedMedia", features: [
        { name: "prefers-reduced-motion", value: "reduce" },
        { name: "forced-colors", value: "active" }
      ])
      visit_browser("/components/ai_chat_tool_call")
    end

    it "pulses the spinner instead of turning it, and keeps the connectors in a system colour" do
      seen = js(<<~JS)
        const canvasText = document.createElement("span")
        canvasText.style.backgroundColor = "CanvasText"
        document.body.append(canvasText)
        const system = getComputedStyle(canvasText).backgroundColor
        const run = document.querySelector("#state_running")
        run.querySelector("details").open = true
        await repaint()
        return {
          reduced: matchMedia("(prefers-reduced-motion: reduce)").matches,
          forced: matchMedia("(forced-colors: active)").matches,
          animation: getComputedStyle(run.querySelector(".UnmagicAIChatSpinner")).animationName,
          join: getComputedStyle(document.querySelector("[data-ai-chat-timeline] + unmagic-tool-call[data-ai-chat-timeline]"), "::before").backgroundColor === system,
          rail: getComputedStyle(run.querySelector("details"), "::after").backgroundColor === system
        }
      JS

      expect(seen).to eq("reduced" => true, "forced" => true, "animation" => "unmagic-ai-chat-pulse", "join" => true, "rail" => true)
    end

    it "still opens a fold from the keyboard" do
      js('document.querySelector("#state_running summary").focus()')
      session.press(:enter)

      expect(js('return document.querySelector("#state_running details").open')).to be(true)
    end
  end

  describe "without JavaScript" do
    before do
      session.driver.javascript_enabled = false
      visit_browser("/components/ai_chat_tool_call", defined: nil)
    end

    # The DevTools protocol still evaluates while the page's own scripts are off,
    # but its timers don't fire, so nothing here awaits one.
    it "folds and unfolds natively, reads the state, and keeps every payload and result on the page" do
      page = js(<<~JS)
        const call = document.querySelector("#state_done")
        const details = call.querySelector("details")
        const before = details.open
        details.querySelector("summary").click()
        return {
          upgraded: !!customElements.get("unmagic-tool-call"),
          toggled: [ before, details.open ],
          status: document.querySelector("#state_failed [data-tool-call-glyph] .UnmagicVisuallyHidden").textContent,
          calls: [ ...document.querySelectorAll("#tool_call_states unmagic-tool-call") ].map(call => ({
            figures: call.querySelectorAll("details > figure").length > 0,
            result: call.querySelector("details ~ *").checkVisibility()
          }))
        }
      JS

      expect(page["upgraded"]).to be(false)
      expect(page["toggled"]).to eq([ false, true ])
      expect(page["status"]).to eq("Failed")
      expect(page["calls"].size).to eq(states.size)
      expect(page["calls"]).to all(eq("figures" => true, "result" => true))
    end
  end
end
