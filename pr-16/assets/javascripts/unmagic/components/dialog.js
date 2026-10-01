// Behaviour every native <dialog> the components render shares. It is wired once,
// by delegation from the document, so a dialog that is streamed or morphed in later
// needs no setup of its own:
//
//   [data-unmagic-dialog-open="ID"]  opens that dialog modally
//   [data-unmagic-dialog-close]      closes the dialog it sits in
//   the backdrop of a dialog[data-unmagic-dialog] closes it on click
//
// A backdrop click only counts when the press also started on the backdrop.
// Selecting text in an input and letting go past the panel's edge fires a click on
// the dialog too, and that shouldn't throw the form away.
//
// A dialog whose panel says aria-busy (a form mid-submit, an upload) refuses to
// close on Escape or the backdrop until it isn't; the close button still works.

const installed = Symbol.for("unmagic-components.dialog")

if (!globalThis[installed]) {
  globalThis[installed] = true

  let pressed = null
  document.addEventListener("pointerdown", (event) => (pressed = event.target), true)

  document.addEventListener("click", (event) => {
    const target = event.target
    if (!(target instanceof Element)) return

    const opener = target.closest("[data-unmagic-dialog-open]")
    if (opener) {
      const dialog = document.getElementById(opener.getAttribute("data-unmagic-dialog-open"))
      if (dialog instanceof HTMLDialogElement) {
        event.preventDefault()
        if (!dialog.open) dialog.showModal()
      }
      return
    }

    const closer = target.closest("[data-unmagic-dialog-close]")
    if (closer) {
      closer.closest("dialog")?.close()
      return
    }

    if (target instanceof HTMLDialogElement && target.matches("[data-unmagic-dialog]") && pressed === target && !busy(target)) {
      target.close()
    }
  })

  document.addEventListener("cancel", (event) => {
    if (event.target instanceof HTMLDialogElement && busy(event.target)) event.preventDefault()
  }, true)

  function busy(dialog) {
    return dialog.matches("[aria-busy=true]") || dialog.querySelector("[aria-busy=true]") !== null
  }

  // An open dialog must not be in the snapshot Turbo restores on Back: it would
  // come back open but not modal, sitting in the page with no backdrop.
  document.addEventListener("turbo:before-cache", () => {
    document.querySelectorAll("dialog[data-unmagic-dialog][open]").forEach((dialog) => dialog.close())
  })
}
