// A board's "Add a card" and "Add a list" forms (`board`), wired once by
// delegation so a column streamed in later works with no setup.
//
// Opening one focuses its field. Enter submits and Shift+Enter makes a new line.
// Escape, or the × button, closes it. After a successful submit the form is reset
// and stays open with the field focused, so several can be added in a row: the
// refresh that follows would otherwise morph the <details> shut, since the
// server's markup has it closed.

const INSTALLED = Symbol.for("unmagic.components.board")

if (!document[INSTALLED]) {
  document[INSTALLED] = true

  // toggle doesn't bubble, but it does pass through the capture phase.
  document.addEventListener(
    "toggle",
    (event) => {
      const details = event.target
      if (details instanceof HTMLDetailsElement && details.matches(".UnmagicBoard__add") && details.open) {
        details.querySelector("[data-board-add-field]")?.focus()
      }
    },
    true,
  )

  document.addEventListener("turbo:before-morph-attribute", (event) => {
    if (event.detail?.attributeName === "open" && event.target.matches?.(".UnmagicBoard__add")) {
      event.preventDefault()
    }
  })

  document.addEventListener("keydown", (event) => {
    const field = event.target
    if (!(field instanceof HTMLTextAreaElement) || !field.hasAttribute("data-board-add-field")) return

    if (event.key === "Escape") {
      event.preventDefault()
      close(field)
    } else if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      field.form?.requestSubmit()
    }
  })

  document.addEventListener("click", (event) => {
    const button = event.target instanceof Element && event.target.closest("[data-board-add-cancel]")
    if (button) close(button)
  })

  document.addEventListener("turbo:submit-end", (event) => {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || !form.hasAttribute("data-board-add") || !event.detail?.success) return

    form.reset()
    form.querySelector("[data-board-add-field]")?.focus()
  })
}

function close(within) {
  const details = within.closest(".UnmagicBoard__add")
  if (!details) return
  details.open = false
  details.querySelector("summary")?.focus()
}
