// <unmagic-modal> — the shared modal a layout mounts with `modal_frame`. It wraps a
// <dialog> holding the turbo frame that modal links load into.
//
// The dialog opens when the frame starts fetching, not when the response lands, so a
// slow form shows a skeleton instead of nothing. The GET check keeps the form's own
// submit from flashing the skeleton again. The prefetch check ignores Turbo's hover
// prefetch, which is also a GET on the frame; without it, merely pointing at a modal
// link would open the dialog.
//
// A failed load swaps in the error template rather than leaving the skeleton
// stranded or letting Turbo print "Content missing". Three failures are caught:
//   - a network error (turbo:fetch-request-error)
//   - an error status whose body lacks the frame (turbo:frame-missing)
//   - an error status with an empty body, which Turbo otherwise ignores
//     (turbo:before-fetch-response)
// The error's retry button reloads the frame, which shows the skeleton again.
//
// A successful submit doesn't close the dialog straight away. The save usually
// answers with a turbo_stream.refresh (see DialogResponder), and closing at once
// would show the stale page for as long as that refresh takes. Instead the dialog
// stays over the page and closes at turbo:before-render, the same render in which
// the morph replaces the page, so the page repaints once. Until then the submit
// button stays disabled and keeps its "Saving…" label. Other responses:
//   - a stream that doesn't refresh: the dialog closes as soon as it is read
//   - a redirect to a page without the frame: the modal visits that page and
//     closes as it renders
//   - a response that renders into the frame (the next step of a wizard): the
//     dialog stays open

import "unmagic/components/dialog"

class UnmagicModal extends HTMLElement {
  #pendingClose = false
  #loadingFrame = false

  connectedCallback() {
    this.addEventListener("turbo:before-fetch-request", this.#loading)
    this.addEventListener("turbo:before-fetch-response", this.#response)
    this.addEventListener("turbo:frame-load", this.#loaded)
    this.addEventListener("turbo:frame-missing", this.#missing)
    this.addEventListener("turbo:fetch-request-error", this.#failed)
    this.addEventListener("turbo:submit-end", this.#submitted)
    this.addEventListener("click", this.#retry)
    // close doesn't bubble, so listen on the way down.
    this.addEventListener("close", this.#reset, true)
    document.addEventListener("turbo:before-render", this.#beforeRender)
  }

  disconnectedCallback() {
    this.removeEventListener("turbo:before-fetch-request", this.#loading)
    this.removeEventListener("turbo:before-fetch-response", this.#response)
    this.removeEventListener("turbo:frame-load", this.#loaded)
    this.removeEventListener("turbo:frame-missing", this.#missing)
    this.removeEventListener("turbo:fetch-request-error", this.#failed)
    this.removeEventListener("turbo:submit-end", this.#submitted)
    this.removeEventListener("click", this.#retry)
    this.removeEventListener("close", this.#reset, true)
    document.removeEventListener("turbo:before-render", this.#beforeRender)
  }

  get dialog() {
    return this.querySelector(":scope > dialog")
  }

  get frame() {
    return this.dialog?.querySelector(":scope > turbo-frame")
  }

  close() {
    this.dialog?.close()
  }

  #loading = (event) => {
    // Only the frame's own navigation. A GET form inside the dialog (a filter) is
    // targeted at the form and shouldn't blank the dialog with a skeleton.
    if (event.target !== this.frame) return

    const fetchOptions = event.detail?.fetchOptions
    if (fetchOptions?.method?.toLowerCase() !== "get") return
    if (fetchOptions.headers?.["X-Sec-Purpose"] === "prefetch") return

    this.#loadingFrame = true
    this.#side(this.#sideOf(event))
    this.#fill("skeleton")
    if (!this.dialog.open) this.dialog.showModal()
  }

  // The side a modal link asked for (data-unmagic-modal-side), read from the
  // link that started the fetch, so the skeleton opens where the panel will.
  #sideOf(event) {
    const link = document.activeElement instanceof Element && document.activeElement.closest("[data-unmagic-modal-side]")
    return link?.getAttribute("data-unmagic-modal-side") ?? event.target.closest?.("[data-unmagic-modal-side]")?.getAttribute("data-unmagic-modal-side") ?? null
  }

  #side(side) {
    if (side && side !== "center") this.dialog.setAttribute("data-side", side)
    else this.dialog.removeAttribute("data-side")
  }

  #response = (event) => {
    if (this.#loadingFrame && !event.detail?.fetchResponse?.succeeded) this.#fail()
  }

  #loaded = () => {
    this.#loadingFrame = false
    this.#label()
    const panel = this.frame.querySelector(".UnmagicDialog[data-side]")
    if (panel) this.#side(panel.getAttribute("data-side"))
  }

  #missing = (event) => {
    if (!this.dialog.open) return
    event.preventDefault()

    const { response, visit } = event.detail
    if (response.ok) {
      this.#pendingClose = true
      visit(response)
    } else {
      this.#fail()
    }
  }

  #failed = () => {
    if (this.dialog.open) this.#fail()
  }

  #fail() {
    this.#loadingFrame = false
    this.#fill("error")
  }

  #submitted = async (event) => {
    const { success, fetchResponse, formSubmission } = event.detail
    if (!success || !fetchResponse?.contentType?.includes("turbo-stream")) return

    this.#pendingClose = true
    this.#holdSubmitter(formSubmission?.submitter)

    const html = await fetchResponse.responseHTML
    if (this.#pendingClose && !/<turbo-stream[^>]*action="refresh"/.test(html ?? "")) this.close()
  }

  // Turbo has just re-enabled the submitter and restored its idle label. Keep it
  // disabled, still saying "Saving…", until the dialog actually closes.
  #holdSubmitter(submitter) {
    if (!submitter) return

    submitter.setAttribute("disabled", "")
    const submitting = submitter.getAttribute("data-turbo-submits-with")
    if (!submitting) return

    if (submitter.matches("input")) submitter.value = submitting
    else submitter.textContent = submitting
  }

  #beforeRender = () => {
    if (this.#pendingClose) this.close()
  }

  #retry = (event) => {
    if (!(event.target instanceof Element) || !event.target.closest("[data-unmagic-modal-retry]")) return
    if (this.frame.getAttribute("src")) this.frame.reload()
  }

  #reset = (event) => {
    if (event.target !== this.dialog) return

    // close is dispatched a task after dialog.close(). If a modal link reopened
    // the dialog in between, its load is already under way; resetting now would
    // abort that fetch and leave the dialog open and blank.
    if (this.dialog.open) return

    this.#pendingClose = false
    this.#loadingFrame = false
    this.frame.removeAttribute("src")
    this.frame.replaceChildren()
    this.dialog.removeAttribute("aria-labelledby")
    this.dialog.removeAttribute("data-side")
  }

  #fill(name) {
    const template = this.dialog.querySelector(`:scope > template[data-unmagic-modal-${name}]`)
    if (!template) return

    this.frame.replaceChildren(template.content.cloneNode(true))
    this.#label()
  }

  // Name the dialog after whatever panel title it is showing.
  #label() {
    const title = this.frame.querySelector(".UnmagicDialog__title[id]")
    if (title) this.dialog.setAttribute("aria-labelledby", title.id)
    else this.dialog.removeAttribute("aria-labelledby")
  }
}

customElements.get("unmagic-modal") || customElements.define("unmagic-modal", UnmagicModal)
