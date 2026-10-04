# frozen_string_literal: true

require "e2e_helper"

RSpec.describe "ai_chat_tool_call in a browser" do
  states = %w[queued running waiting done failed]
  legacy = "div.UnmagicAIChatToolCall, .UnmagicAIChatToolCall__join, .UnmagicAIChatToolCall__rail"

  # The direct-HTML example has no payload. Streaming one in is where most of
  # the element's work starts, so the examples below share this opening.
  stream_payload = <<~JS
    let call = document.querySelector("#element_direct")
    const source = call.cloneNode(true)
    const payload = document.createElement("div")
    payload.dataset.part = "payload"
    payload.textContent = "config/database.yml"
    call.append(payload)
    await settle()
  JS

  # The same, opened by the helper and then shut by the reader, which is a
  # choice the element has to keep from then on.
  shut_by_reader = <<~JS
    document.querySelector("#element_direct").setAttribute("open", "")
    #{stream_payload}
    const startedOpen = call.querySelector("details").open
    call.querySelector("summary").click()
    await settle()
  JS

  describe "on the component's page" do
    before { visit_browser("/components/ai_chat_tool_call") }

    it "folds a payload away and keeps the result outside, for the helper and direct HTML alike" do
      expect(js(<<~JS)).to eq("legacy" => false, "helper" => true, "result_folded" => false, "direct" => false)
        const helper = document.querySelector("#element_search")
        return {
          legacy: !!document.querySelector(#{legacy.to_json}),
          helper: !!helper.querySelector("details"),
          result_folded: !!helper.querySelector('details [data-part="result"]'),
          direct: !!document.querySelector("#element_direct details")
        }
      JS
    end

    it "shows each state's disclosure, busy state and progress" do
      shown = js(<<~JS)
        return Object.fromEntries(#{states.to_json}.map(state => {
          const call = document.querySelector(`#element_state_${state}`)
          return [ state, {
            disclosure: !!call.querySelector("details"),
            busy: call.getAttribute("aria-busy") === "true",
            progress: !call.querySelector('[data-part="progress"]').hidden
          } ]
        }))
      JS

      expect(shown).to eq(states.to_h { |state|
        [ state, { "disclosure" => true, "busy" => state == "running", "progress" => state == "running" } ]
      })
    end

    it "orders the progress line after the disclosure arrow, so the arrow can't wrap below it" do
      expect(js(<<~JS)).to eq("1")
        return getComputedStyle(document.querySelector("#tool_call_element_states .UnmagicAIChatToolCall__progress")).order
      JS
    end

    it "joins neighbouring calls with a line, and stops at a message or a call outside the timeline" do
      joined = js(<<~JS)
        const ids = [ "element_direct", "mixed_element", "mixed_helper_after", "mixed_after_break", "mixed_standalone" ]
        return Object.fromEntries(ids.map(id => [ id, getComputedStyle(document.getElementById(id), "::before").content !== "none" ]))
      JS

      expect(joined).to eq(
        "element_direct" => true, "mixed_element" => true, "mixed_helper_after" => true,
        "mixed_after_break" => false, "mixed_standalone" => false
      )
    end

    it "wraps a streamed payload in a disclosure without replacing nodes, dropping listeners or hiding the focus" do
      expect(js(<<~JS)).to eq("open" => true, "row" => true, "input" => true, "focused" => true, "clicks" => 1)
        const call = document.querySelector("#element_direct")
        const row = call.querySelector('[data-part="row"]')
        let clicks = 0
        const payload = document.createElement("div")
        payload.dataset.part = "payload"
        const input = document.createElement("input")
        input.setAttribute("aria-label", "Streamed content")
        input.addEventListener("click", () => clicks++)
        payload.append(input)
        call.append(payload)
        input.focus()
        await settle()
        input.click()
        return {
          open: call.querySelector("details")?.open,
          row: call.querySelector('[data-part="row"]') === row,
          input: call.querySelector("input") === input,
          focused: document.activeElement === input,
          clicks
        }
      JS
    end

    it "keeps the reader's choice through a replacement, and through its payload leaving and returning" do
      expect(js(<<~JS)).to eq(
        #{shut_by_reader}
        const replacement = source.cloneNode(true)
        replacement.setAttribute("open", "")
        replacement.append(payload)
        call.replaceWith(replacement)
        call = replacement
        await settle()
        const replaced = call.querySelector("details").open

        call.querySelector("summary").focus()
        payload.remove()
        await settle()
        const emptied = !!call.querySelector("details")
        const focus = document.activeElement === call.querySelector('[data-part="row"]')

        call.append(payload)
        await settle()
        return { started_open: startedOpen, replaced, emptied, focus, returned: call.querySelector("details").open }
      JS
        "started_open" => true, "replaced" => false, "emptied" => false, "focus" => true, "returned" => false
      )
    end

    it "remembers on its own whether a call with no id was open, while its payload is away" do
      expect(js(<<~JS)).to eq("opened" => true, "emptied" => false, "returned" => true)
        document.querySelector("#element_direct").removeAttribute("id")
        const call = document.querySelector("#tool_call_element_demo unmagic-tool-call:not([id])")
        const payload = document.createElement("div")
        payload.dataset.part = "payload"
        call.append(payload)
        await settle()
        call.querySelector("summary").click()
        await settle()
        const opened = call.querySelector("details").open
        payload.remove()
        await settle()
        const emptied = !!call.querySelector("details")
        call.append(payload)
        await settle()
        return { opened, emptied, returned: call.querySelector("details").open }
      JS
    end

    it "adopts a Turbo Stream append, lets go on remove, and survives a morph with the reader's choice" do
      expect(js(<<~JS)).to eq("turbo" => true, "appended" => true, "removed" => true, "disclosures" => 1, "open" => false)
        #{shut_by_reader}
        Turbo.renderStreamMessage(`<turbo-stream action="append" target="${call.id}"><template><div data-part="payload" id="element_turbo_payload">Turbo payload</div></template></turbo-stream>`)
        await repaint()
        const appended = !!call.querySelector("[data-tool-call-body] > #element_turbo_payload")

        Turbo.renderStreamMessage('<turbo-stream action="remove" target="element_turbo_payload"></turbo-stream>')
        await repaint()
        const removed = !document.querySelector("#element_turbo_payload")

        const incoming = source.cloneNode(true)
        incoming.setAttribute("open", "")
        incoming.append(payload.cloneNode(true))
        Turbo.renderStreamMessage(`<turbo-stream action="replace" method="morph" target="${call.id}"><template>${incoming.outerHTML}</template></turbo-stream>`)
        await repaint()
        call = document.querySelector("#element_direct")
        return {
          turbo: !!window.Turbo, appended, removed,
          disclosures: call.querySelectorAll(":scope > details").length,
          open: call.querySelector("details").open
        }
      JS
    end

    it "keeps one disclosure when it is cloned, as a Turbo snapshot is, or moved" do
      expect(js(<<~JS)).to eq("cloned" => 1, "moved" => 1)
        #{stream_payload}
        const clone = call.cloneNode(true)
        call.replaceWith(clone)
        await settle()
        const cloned = clone.querySelectorAll("details").length
        clone.remove()
        document.querySelector("#tool_call_element_demo").append(clone)
        await settle()
        return { cloned, moved: clone.querySelectorAll("details").length }
      JS
    end

    it "leaves a nested call's payload with the nested call" do
      expect(js(<<~JS)).to eq("owner" => true, "outer_payloads" => 1)
        #{stream_payload}
        const nested = source.cloneNode(true)
        nested.removeAttribute("id")
        call.querySelector('[data-part="result"]').append(nested)
        const nestedPayload = document.createElement("div")
        nestedPayload.dataset.part = "payload"
        nestedPayload.textContent = "Nested result"
        nested.append(nestedPayload)
        await settle()
        return {
          owner: nestedPayload.closest("unmagic-tool-call") === nested,
          outer_payloads: call.querySelectorAll(':scope > details > [data-tool-call-body] > [data-part="payload"]').length
        }
      JS
    end

    it "counts an empty payload as a payload, and doesn't undo a click that lands with a content update" do
      expect(js(<<~JS)).to eq("empty" => true, "open" => true)
        #{stream_payload}
        payload.replaceChildren()
        await settle()
        const empty = !!call.querySelector("details")
        payload.textContent = "Streamed payload arrived without a Ruby redraw."
        call.querySelector("summary").click()
        await settle()
        return { empty, open: call.querySelector("details").open }
      JS
    end

    it "moves through every state by property and by attribute, leaving content, focus and selection alone" do
      sequence = %w[queued running waiting done failed running]
      steps = js(<<~JS)
        const call = document.querySelector("#element_state_running")
        const disclosure = call.querySelector("details")
        disclosure.open = true
        const payload = call.querySelector('[data-part="payload"]')
        const field = document.createElement("input")
        field.setAttribute("aria-label", "Keep focus during state updates")
        field.value = "Selected text"
        payload.append(field)
        field.focus()
        field.setSelectionRange(0, 8)
        const shown = part => !call.querySelector(`[data-part="${part}"]`).hidden
        const steps = []
        for (const [ index, state ] of #{sequence.to_json}.entries()) {
          if (index % 2) call.setAttribute("state", state)
          else call.state = state
          await settle()
          steps.push({
            property: call.state,
            attribute: call.getAttribute("state"),
            disclosure: call.querySelector("details") === disclosure && disclosure.open,
            payload: call.querySelector('[data-part="payload"]') === payload,
            focus: document.activeElement === field && field.selectionEnd === 8,
            busy: call.getAttribute("aria-busy") === "true",
            status: call.querySelector("[data-tool-call-glyph] .UnmagicVisuallyHidden").textContent === call.getAttribute(`label-${state}`),
            progress: shown("progress"), failures: shown("failures"), elapsed: shown("elapsed"), duration: shown("duration"),
            folder: !!call.querySelector("[data-tool-call-glyph] svg").dataset.unmagicIcon?.endsWith("/folder")
          })
        }
        return steps
      JS

      expect(steps).to eq(sequence.map { |state|
        running = state == "running"
        {
          "property" => state, "attribute" => state, "disclosure" => true, "payload" => true, "focus" => true,
          "busy" => running, "status" => true, "progress" => running, "failures" => state != "failed",
          "elapsed" => running, "duration" => !running, "folder" => state == "done"
        }
      })
    end

    it "relabels a state when its label attribute changes" do
      expect(js(<<~JS)).to eq("En cours")
        const call = document.querySelector("#element_state_running")
        call.setAttribute("label-running", "En cours")
        return call.querySelector("[data-tool-call-glyph]").textContent
      JS
    end

    it "rejects an unknown state as a property, and reads one in the attribute as queued" do
      expect(js(<<~JS)).to eq("rejected" => true, "kept" => "running", "invalid" => "queued", "busy" => false, "absent" => "queued")
        const call = document.querySelector("#element_state_running")
        let rejected = false
        try { call.state = "invalid" } catch (error) { rejected = error instanceof TypeError }
        const kept = call.state
        call.setAttribute("state", "invalid")
        const invalid = call.state
        const busy = call.hasAttribute("aria-busy")
        call.removeAttribute("state")
        return { rejected, kept, invalid, busy, absent: call.state }
      JS
    end

    it "moves the focus to the summary when the progress it was in is hidden" do
      expect(js(<<~JS)).to be(true)
        const call = document.querySelector("#element_state_running")
        const control = document.createElement("input")
        control.setAttribute("aria-label", "Progress control")
        call.querySelector('[data-part="progress"]').append(control)
        await settle()
        control.focus()
        call.state = "failed"
        return document.activeElement === call.querySelector("summary")
      JS
    end

    it "draws one glyph for a clone of an already upgraded call" do
      expect(js(<<~JS)).to eq("state" => "done", "glyphs" => 1)
        const clone = document.querySelector("#element_state_done").cloneNode(true)
        clone.id = "element_state_clone"
        document.querySelector("#element_state_done").after(clone)
        await settle()
        return { state: clone.state, glyphs: clone.querySelectorAll("[data-tool-call-glyph]").length }
      JS
    end

    it "reflects the name property to the attribute and the row" do
      expect(js(<<~JS)).to eq("attribute" => "updated_name", "text" => "updated_name")
        const call = document.querySelector("#element_direct")
        call.name = "updated_name"
        return { attribute: call.getAttribute("name"), text: call.querySelector('[data-part="name"]').textContent }
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
        it "upgrades #{consumer} #{rendering}, and answers the keyboard and state changes there" do
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
              const call = calls.find(node => node.querySelector(":scope > details"))
              const details = call.querySelector("details")
              call.scrollIntoView({ block: "center" })
              details.open = false
              details.querySelector("summary").focus()
              window.e2eCall = call
              return {
                path: location.pathname,
                theme: document.documentElement.dataset.theme,
                calls: calls.length,
                legacy: !!document.querySelector(#{legacy.to_json}),
                upgraded: calls.every(node => node.querySelector("[data-tool-call-glyph]")),
                keyed: calls.every(node => !node.id || !node.querySelector(":scope > details") || node.querySelector(":scope > details").dataset.aiChatDisclosure === node.id)
              }
            JS

            expect(page).to include(
              "path" => "#{E2EHelpers::MOUNT}#{path}", "theme" => emulation[:theme],
              "legacy" => false, "upgraded" => true, "keyed" => true
            )
            expect(page["calls"]).to be > 0

            session.press(:enter)

            expect(js(<<~JS)).to all(eq("reflected" => true, "disclosure" => true, "payload" => true, "focus" => true))
              const call = window.e2eCall
              const details = call.querySelector("details")
              const summary = details.querySelector("summary")
              const payload = details.querySelector('[data-part="payload"]')
              const opened = details.open
              const steps = []
              for (const state of [ "running", "waiting", "done", "failed" ]) {
                call.state = state
                await settle()
                steps.push({
                  reflected: call.getAttribute("state") === state,
                  disclosure: opened && details.open && call.querySelector("details") === details,
                  payload: call.querySelector('[data-part="payload"]') === payload,
                  focus: document.activeElement === summary
                })
              }
              return steps
            JS
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

    it "pulses the spinner instead of turning it, and keeps the connector in a system colour" do
      seen = js(<<~JS)
        const canvasText = document.createElement("span")
        canvasText.style.backgroundColor = "CanvasText"
        document.body.append(canvasText)
        return {
          reduced: matchMedia("(prefers-reduced-motion: reduce)").matches,
          forced: matchMedia("(forced-colors: active)").matches,
          animation: getComputedStyle(document.querySelector("#element_state_running .UnmagicAIChatSpinner")).animationName,
          connector: getComputedStyle(document.querySelector("#mixed_element"), "::before").backgroundColor === getComputedStyle(canvasText).backgroundColor
        }
      JS

      expect(seen).to eq("reduced" => true, "forced" => true, "animation" => "unmagic-ai-chat-pulse", "connector" => true)
    end

    it "still opens a disclosure from the keyboard" do
      js('document.querySelector("#element_state_running summary").focus()')
      session.press(:enter)

      expect(js('return document.querySelector("#element_state_running details").open')).to be(true)
    end
  end

  describe "without JavaScript" do
    before do
      session.driver.javascript_enabled = false
      visit_browser("/components/ai_chat_tool_call", defined: nil)
    end

    # The DevTools protocol still evaluates while the page's own scripts are off.
    it "leaves every payload and result readable, with nothing folded away" do
      page = js(<<~JS)
        return {
          upgraded: !!customElements.get("unmagic-tool-call"),
          calls: [ ...document.querySelectorAll("#tool_call_element_states unmagic-tool-call") ].map(call => ({
            disclosure: !!call.querySelector("details"),
            payload: call.querySelector('[data-part="payload"]').checkVisibility(),
            result: call.querySelector('[data-part="result"]').checkVisibility()
          }))
        }
      JS

      expect(page["upgraded"]).to be(false)
      expect(page["calls"].size).to eq(states.size)
      expect(page["calls"]).to all(eq("disclosure" => false, "payload" => true, "result" => true))
    end
  end
end
