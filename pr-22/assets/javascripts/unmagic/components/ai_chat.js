// The AI chat components' behaviour on plain elements, wired once by delegation
// from the document so a composer, a suggestion or a question streamed in later
// needs no setup.
//
// The composer (`ai_chat_composer`):
//   - Enter sends and Shift+Enter makes a new line, but only while the form's Send
//     button is on the page. While a turn runs it is Stop, so Enter does nothing
//     rather than failing quietly. Composing text (an IME) is left alone.
//   - After a successful submit the form is reset rather than the field blanked,
//     so <unmagic-uuid-input> mints the next id and autogrow re-measures. A failed
//     request leaves what was typed where it was.
//
// Suggestions (`ai_chat_welcome`): pressing one fills the composer and sends it,
// unless it is marked to fill only, or a turn is running.
//
// Questions and permission requests (`ai_chat_request`, `ai_chat_permission`)
// streamed in with role="alert" take focus when nothing else has it — the first
// option of a question, the card itself for a permission, never its Allow button.
// Someone typing in the composer keeps their focus.
//
// Branch pickers (`ai_chat_branch_picker`): moving to another version replaces the
// turn, so focus goes back to the same step in the replacement, and a reader can
// keep stepping without finding the control again.
//
// Disclosures (a plan or workspace section, a tool call's details, reasoning):
// each is a <details> the server renders open or shut, and each is broadcast over
// while the agent works, which would put it back to the server's open: every
// time. One marked data-ai-chat-disclosure="<id>" (the helpers mark those given
// an id) keeps what the person last chose, clicking its summary, across a stream
// that replaces it and a morph that would reset it. Until they choose, the server
// decides. Without this script the server always decides, as plain <details> do.
// The choices last until the page is loaded afresh.

const INSTALLED = Symbol.for("unmagic.components.ai_chat")

if (!document[INSTALLED]) {
  document[INSTALLED] = true

  document.addEventListener("keydown", (event) => {
    const field = event.target
    if (!(field instanceof HTMLTextAreaElement) || !field.hasAttribute("data-ai-chat-composer-field")) return
    if (event.key !== "Enter" || event.shiftKey || event.isComposing || event.defaultPrevented) return

    event.preventDefault()
    const form = field.form
    const send = form && sendButton(form)
    if (send) form.requestSubmit(send)
  })

  document.addEventListener("turbo:submit-end", (event) => {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || !event.detail?.success) return

    const field = form.querySelector("[data-ai-chat-composer-field]")
    if (!field) return

    form.reset()
    field.focus()
  })

  document.addEventListener("click", (event) => {
    const button = event.target instanceof Element && event.target.closest("[data-ai-chat-suggestion]")
    if (button) suggest(button)
  })

  new MutationObserver((records) => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (!(node instanceof Element)) continue
        keepChoices(node)
        arrive(node)
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true })

  // The toggle is the click's default action and its event comes later, so a
  // click on a marked summary only notes which disclosure the person is moving.
  // The toggle event doesn't bubble, hence the capture.
  let moving = null

  document.addEventListener("click", (event) => {
    const summary = event.target instanceof Element && event.target.closest("summary")
    const details = summary?.parentElement
    moving = details?.matches(DISCLOSURE) && details.querySelector(":scope > summary") === summary ? details : null
  })

  document.addEventListener("toggle", (event) => {
    if (event.target !== moving) return
    moving = null
    choices.set(event.target.dataset.aiChatDisclosure, event.target.open)
  }, true)

  // A morph keeps the element and would set its open attribute back; refuse that.
  document.addEventListener("turbo:before-morph-attribute", (event) => {
    const details = event.target
    if (event.detail.attributeName !== "open" || !(details instanceof HTMLDetailsElement)) return
    if (details.matches(DISCLOSURE) && choices.has(details.dataset.aiChatDisclosure)) event.preventDefault()
  })

  let pendingStep = null

  document.addEventListener("click", (event) => {
    const step = event.target instanceof Element && event.target.closest(".UnmagicAIChatBranchPicker__step")
    if (!step) return

    const picker = step.closest(".UnmagicAIChatBranchPicker")
    const turn = picker?.parentElement?.closest("[id]")
    if (!turn) return

    pendingStep = { turn: turn.id, index: Array.from(picker.querySelectorAll(".UnmagicAIChatBranchPicker__step")).indexOf(step) }
  })

  const restoreStep = () => {
    if (!pendingStep) return
    const steps = document.getElementById(pendingStep.turn)?.querySelectorAll(".UnmagicAIChatBranchPicker__step")
    if (!steps) return

    const step = steps[pendingStep.index]
    pendingStep = null
    const target = step?.getAttribute("aria-disabled") === "true" ? Array.from(steps).find((other) => other !== step) : step
    target?.focus()
  }

  document.addEventListener("turbo:before-stream-render", (event) => {
    if (!pendingStep) return
    const render = event.detail.render
    event.detail.render = async (stream) => {
      await render(stream)
      restoreStep()
    }
  })
  document.addEventListener("turbo:render", restoreStep)
  document.addEventListener("turbo:frame-render", restoreStep)
}

// The form's own Send button: the one submit that names the form. Stop names a
// different form, so its presence doesn't count.
function sendButton(form) {
  if (!form.id) return form.querySelector("button[type=submit]:not([form])")
  return document.querySelector(`button[type=submit][form="${CSS.escape(form.id)}"]`)
}

function suggest(button) {
  const form = document.getElementById(button.dataset.aiChatSuggestionForm)
  if (!(form instanceof HTMLFormElement)) return

  const name = button.dataset.aiChatSuggestionField
  const field =
    (name && form.elements.namedItem(name)) ||
    form.querySelector("[data-ai-chat-composer-field]") ||
    form.querySelector("textarea")
  if (!field) return

  field.value = button.dataset.aiChatSuggestion
  field.dispatchEvent(new Event("input", { bubbles: true }))
  field.focus()
  field.selectionStart = field.selectionEnd = field.value.length

  if ("aiChatSuggestionFill" in button.dataset) return
  const send = sendButton(form)
  if (send) form.requestSubmit(send)
}

const DISCLOSURE = "details[data-ai-chat-disclosure]"

// What the person last chose for each disclosure, by its id: true for open.
const choices = new Map()

// Runs from the MutationObserver, before the replacement is painted, so a shut
// section never flashes open.
function keepChoices(node) {
  const found = node.matches(DISCLOSURE) ? [ node ] : node.querySelectorAll(DISCLOSURE)
  for (const details of found) {
    const open = choices.get(details.dataset.aiChatDisclosure)
    if (open !== undefined && details.open !== open) details.open = open
  }
}

const ASKING = ".UnmagicAIChatRequest--waiting[role=alert], .UnmagicAIChatPermission--waiting[role=alert]"

function arrive(node) {
  const card = node.matches(ASKING) ? node : node.querySelector(ASKING)
  if (!card) return

  const focused = document.activeElement
  if (focused && focused !== document.body && focused !== document.documentElement) return

  if (card.classList.contains("UnmagicAIChatPermission")) {
    card.focus()
  } else {
    const first = card.querySelector("input:not([type=hidden]), select, textarea")
    ;(first ?? card).focus()
  }
}
