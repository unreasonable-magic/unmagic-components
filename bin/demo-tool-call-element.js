// Visit /components/ai_chat_tool_call, then paste this file into Chrome's console.
// It can also be passed verbatim to Chrome DevTools MCP evaluate_script as a function.
// Await runToolCallElementDemo() to replay. No server writes; reload resets the demo.
async function runToolCallElementDemo() {
  const pause = () => new Promise(resolve => setTimeout(resolve, 150))
  const assert = (condition, message) => { if (!condition) throw new Error(message) }
  const demo = document.querySelector("#tool_call_element_demo")
  assert(demo, "Open the tool call component browser first")
  await customElements.whenDefined("unmagic-tool-call")
  demo.scrollIntoView({ block: "center" })
  const helper = demo.querySelector("#element_search")
  let call = demo.querySelector("#element_direct")
  const source = call.cloneNode(true)
  const row = call.querySelector('[data-part="row"]')
  assert(helper.querySelector("details"), "Helper payload should create a disclosure")
  assert(!helper.querySelector('details [data-part="result"]'), "Results must stay outside")
  assert(!call.querySelector("details"), "No payload means no disclosure")
  assert(getComputedStyle(call, "::before").content !== "none", "Adjacent call needs a connector")

  const states = document.querySelector("#tool_call_element_states")
  if (states) {
    for (const state of ["queued", "running", "waiting", "done", "failed"]) {
      const example = states.querySelector(`#element_state_${state}`)
      assert(!!example.querySelector("details"), `${state} has no disclosure`)
      assert((example.getAttribute("aria-busy") === "true") === (state === "running"), `${state} busy state incorrect`)
      assert(!example.querySelector('[data-part="progress"]').hidden === (state === "running"), `${state} progress incorrect`)
    }
    const progress = states.querySelector(".UnmagicAIChatToolCall__progress")
    assert(getComputedStyle(progress).order === "1", "Disclosure arrow can wrap below progress")
    assert(getComputedStyle(document.querySelector("#mixed_element"), "::before").content !== "none", "Legacy-to-element join missing")
    assert(getComputedStyle(document.querySelector("#mixed_legacy_after .UnmagicAIChatToolCall__join")).display === "block", "Element-to-legacy join missing")
    for (const id of ["mixed_after_break", "mixed_standalone"]) {
      assert(getComputedStyle(document.getElementById(id), "::before").content === "none", `${id} should not join`)
    }
  }

  let clicks = 0
  const payload = document.createElement("div")
  payload.dataset.part = "payload"
  payload.id = "element_streamed_payload"
  const input = document.createElement("input")
  input.setAttribute("aria-label", "Streamed content")
  input.value = "config/database.yml"
  input.addEventListener("click", () => clicks++)
  payload.append(input)
  call.append(payload)
  input.focus()
  await pause()
  let details = call.querySelector("details")
  assert(details?.open, "Upgrading must not hide a focused payload")
  assert(call.querySelector('[data-part="row"]') === row, "Row identity changed")
  assert(call.querySelector("input") === input, "Payload identity changed")
  assert(document.activeElement === input, "Payload focus lost during upgrade")
  input.click()
  assert(clicks === 1, "Payload listener lost")

  // A real summary activation feeds the shared disclosure choice store.
  details.querySelector("summary").click()
  await pause()
  assert(!details.open, "Summary should close")
  const replacement = source.cloneNode(true)
  replacement.setAttribute("open", "")
  replacement.append(payload)
  call.replaceWith(replacement)
  call = replacement
  await pause()
  details = call.querySelector("details")
  assert(!details.open, "Reader choice lost on ID-keyed replacement")

  details.querySelector("summary").focus()
  payload.remove()
  await pause()
  assert(!call.querySelector("details"), "Last payload removal should remove disclosure")
  assert(document.activeElement === call.querySelector('[data-part="row"]'), "Summary focus not recovered")
  call.append(payload)
  await pause()
  assert(!call.querySelector("details").open, "Choice lost when payload returned")

  if (window.Turbo) {
    Turbo.renderStreamMessage(`<turbo-stream action="append" target="${call.id}"><template><div data-part="payload" id="element_turbo_payload">Turbo payload</div></template></turbo-stream>`)
    await pause()
    assert(call.querySelector('[data-tool-call-body] > #element_turbo_payload'), "Turbo append was not adopted")
    Turbo.renderStreamMessage('<turbo-stream action="remove" target="element_turbo_payload"></turbo-stream>')
    await pause()
    assert(!call.querySelector("#element_turbo_payload"), "Turbo remove failed")
    const incoming = source.cloneNode(true)
    incoming.setAttribute("open", "")
    incoming.append(payload.cloneNode(true))
    Turbo.renderStreamMessage(`<turbo-stream action="replace" method="morph" target="${call.id}"><template>${incoming.outerHTML}</template></turbo-stream>`)
    await pause()
    call = demo.querySelector("#element_direct")
    assert(call.querySelectorAll(":scope > details").length === 1, "Turbo morph duplicated disclosure")
    assert(!call.querySelector("details").open, "Turbo morph lost reader choice")
  }

  const clone = call.cloneNode(true)
  call.replaceWith(clone)
  call = clone
  await pause()
  assert(call.querySelectorAll("details").length === 1, "Snapshot clone duplicated disclosure")
  call.remove()
  demo.append(call)
  await pause()
  assert(call.querySelectorAll("details").length === 1, "Reconnect duplicated disclosure")

  // A nested component's payload must not be adopted by the outer call.
  const nested = source.cloneNode(true)
  nested.removeAttribute("id")
  call.querySelector('[data-part="result"]').append(nested)
  const nestedPayload = document.createElement("div")
  nestedPayload.dataset.part = "payload"
  nestedPayload.textContent = "Nested result"
  nested.append(nestedPayload)
  await pause()
  assert(nestedPayload.closest("unmagic-tool-call") === nested, "Outer call stole nested content")
  nested.remove()

  // Empty payloads are meaningful, unlike an absent payload.
  call.querySelector('[data-part="payload"]').replaceChildren()
  await pause()
  assert(call.querySelector("details"), "Empty payload incorrectly treated as absent")
  call.querySelector('[data-part="payload"]').textContent = "Streamed payload arrived without a Ruby redraw."
  call.querySelector("summary").click()
  helper.querySelector("summary").click()
  await pause()
  assert(call.querySelector("details").open, "A simultaneous content update undid the reader's click")
  // Attribute/property state updates must leave the user's content and choice alone.
  const reactive = document.querySelector("#element_state_running")
  if (reactive) {
    const disclosure = reactive.querySelector("details")
    disclosure.open = true
    const payloadNode = reactive.querySelector('[data-part="payload"]')
    const field = document.createElement("input")
    field.setAttribute("aria-label", "Keep focus during state updates")
    field.value = "Selected text"
    payloadNode.append(field)
    field.focus()
    field.setSelectionRange(0, 8)
    for (const [index, state] of ["queued", "running", "waiting", "done", "failed", "running"].entries()) {
      if (index % 2) reactive.setAttribute("state", state)
      else reactive.state = state
      await pause()
      assert(reactive.state === state && reactive.getAttribute("state") === state, "State reflection disagrees")
      assert(reactive.querySelector("details") === disclosure && disclosure.open, "State change replaced or closed disclosure")
      assert(reactive.querySelector('[data-part="payload"]') === payloadNode && document.activeElement === field && field.selectionEnd === 8, "State change lost content, focus, or selection")
      assert((reactive.getAttribute("aria-busy") === "true") === (state === "running"), "Busy state out of sync")
      assert(reactive.querySelector('[data-tool-call-glyph] .UnmagicVisuallyHidden').textContent === reactive.getAttribute(`label-${state}`), "Accessible status out of sync")
      assert(reactive.querySelector('[data-part="progress"]').hidden === (state !== "running"), "Progress out of sync")
      assert(reactive.querySelector('[data-part="failures"]').hidden === (state === "failed"), "Failure reading out of sync")
      assert(reactive.querySelector('[data-part="elapsed"]').hidden === (state !== "running"), "Elapsed reading out of sync")
      assert(reactive.querySelector('[data-part="duration"]').hidden === (state === "running"), "Duration reading out of sync")
      if (state === "done") assert(reactive.querySelector('[data-tool-call-glyph] svg').dataset.unmagicIcon.endsWith('/folder'), "Custom success glyph missing")
    }
    reactive.setAttribute("label-running", "En cours")
    assert(reactive.querySelector('[data-tool-call-glyph]').textContent === "En cours", "Label update ignored")
    reactive.setAttribute("label-running", "Running")
    let rejected = false
    try { reactive.state = "invalid" } catch (error) { rejected = error instanceof TypeError }
    assert(rejected && reactive.state === "running", "Invalid property changed state")
    reactive.setAttribute("state", "invalid")
    assert(reactive.state === "queued" && !reactive.hasAttribute("aria-busy"), "Invalid attribute did not fall back")
    reactive.removeAttribute("state")
    assert(reactive.state === "queued", "Absent state did not default")
    reactive.state = "done"
    field.remove()
    const progress = reactive.querySelector('[data-part="progress"]')
    const control = document.createElement("input")
    control.setAttribute("aria-label", "Progress control")
    progress.append(control)
    reactive.state = "running"
    control.focus()
    reactive.state = "failed"
    assert(document.activeElement === disclosure.querySelector("summary"), "Focus left in hidden progress")
    control.remove()
    reactive.state = "done"
    const stateClone = reactive.cloneNode(true)
    stateClone.id = "reactive_clone_check"
    reactive.after(stateClone)
    await pause()
    assert(stateClone.state === "done" && stateClone.querySelectorAll('[data-tool-call-glyph]').length === 1, "Restoration duplicated state presentation")
    stateClone.remove()
  }
  call.name = "updated_name"
  assert(call.querySelector('[data-part="name"]').textContent === "updated_name", "Name property did not reflect")
  return { passed: true, turbo: !!window.Turbo, checks: "reactive state/property/labels, timing/failures, invalid state, focus/selection, dynamic disclosure, identity, replacement, clone, reconnect, nested ownership, empty payload, CSS connector, Turbo append/remove/morph" }
}
