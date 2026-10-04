// Start on /components/ai_chat_tool_call and paste into the browser console.
// Run await runToolCallConsumerDemo(). Also accepts Chrome MCP evaluate_script.
// Visits the migrated consumers using Turbo; no server writes. Reload to reset.
async function runToolCallConsumerDemo() {
  const assert = (condition, message) => { if (!condition) throw new Error(message) }
  const pause = () => new Promise(resolve => setTimeout(resolve, 400))
  const prefix = location.pathname.split("/components/ai_chat_tool_call")[0]
  assert(location.pathname.endsWith("/components/ai_chat_tool_call"), "Start on the tool call page")
  const theme = new URL(location.href).searchParams.get("theme") || "light"
  const results = []
  for (const path of ["/components/ai_chat_tool_call", "/components/ai_chat", "/blocks/assistant_workspace/preview"]) {
    if (!location.pathname.endsWith(path)) {
      await new Promise((resolve, reject) => {
        const loaded = () => { clearTimeout(timer); resolve() }
        const timer = setTimeout(() => {
          document.removeEventListener("turbo:load", loaded)
          reject(new Error(`Navigation timed out: ${path}`))
        }, 10000)
        document.addEventListener("turbo:load", loaded, { once: true })
        Turbo.visit(`${prefix}${path}?theme=${theme}`)
      })
    }
    await customElements.whenDefined("unmagic-tool-call")
    await pause()
    const calls = [...document.querySelectorAll("unmagic-tool-call")]
    assert(calls.length > 0, `${path}: no tool calls`)
    assert(!document.querySelector("div.UnmagicAIChatToolCall, .UnmagicAIChatToolCall__join, .UnmagicAIChatToolCall__rail"), `${path}: legacy markup`)
    for (const call of calls) {
      assert(call.querySelector('[data-tool-call-glyph]'), `${path}: call did not upgrade`)
      const details = call.querySelector(":scope > details")
      if (details && call.id) assert(details.dataset.aiChatDisclosure === call.id, `${path}: disclosure ID missing`)
    }
    const call = calls.find(node => node.querySelector(":scope > details"))
    assert(call, `${path}: no disclosure to demonstrate`)
    call.scrollIntoView({ block: "center" })
    const details = call.querySelector("details")
    const summary = details.querySelector("summary")
    const payload = details.querySelector('[data-part="payload"]')
    const originalState = call.state
    const originalOpen = details.open
    if (!details.open) summary.click()
    await pause()
    summary.focus()
    for (const state of ["running", "waiting", "done", "failed"]) {
      call.state = state
      await pause()
      assert(call.getAttribute("state") === state, `${path}: state did not reflect`)
      assert(details.open && call.querySelector("details") === details, `${path}: disclosure was replaced or closed`)
      assert(call.querySelector('[data-part="payload"]') === payload, `${path}: payload was replaced`)
      assert(document.activeElement === summary, `${path}: focus was lost`)
    }
    call.state = originalState
    if (!originalOpen) summary.click()
    results.push({ path, calls: calls.length, passed: true })
  }
  return results
}
