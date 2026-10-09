// Replaces window.confirm for data-turbo-confirm with a dialog in the components'
// own chrome. Importing this module installs it.
//
//   <%= button_to "Delete", label_path(label), method: :delete,
//         form: { data: { turbo_confirm: "Delete this label?",
//                         turbo_confirm_accept: "Delete",
//                         turbo_confirm_variant: "danger" } } %>
//
// Optional attributes, read from the submitter first and then the form:
//   data-turbo-confirm-title    the heading (default "Are you sure?")
//   data-turbo-confirm-accept   the confirming button's label (default "Confirm")
//   data-turbo-confirm-variant  "danger" styles that button as destructive and
//                               focuses Cancel instead
//
// When a link carries data-turbo-method, Turbo builds a form for it and copies only
// data-turbo-confirm onto that form. Use button_to when you need the other
// attributes.
//
// The words come from the page's `confirm_dialog_template`, so they can be
// translated. Without one they fall back to the English defaults below.

import { Turbo } from "@hotwired/turbo-rails"
import "unmagic/components/dialog"

const FALLBACK = `
  <dialog class="UnmagicDialogBox" role="alertdialog" data-unmagic-dialog>
    <form method="dialog" class="UnmagicDialog">
      <header class="UnmagicDialog__header">
        <h2 class="UnmagicDialog__title" data-unmagic-confirm-title>Are you sure?</h2>
      </header>
      <div class="UnmagicDialog__body"><p data-unmagic-confirm-message></p></div>
      <div class="UnmagicDialog__footer">
        <button value="cancel" class="UnmagicButton" data-unmagic-confirm-cancel>Cancel</button>
        <button value="confirm" class="UnmagicButton UnmagicButton--primary" data-unmagic-confirm-accept>Confirm</button>
      </div>
    </form>
  </dialog>`

let sequence = 0

export function confirm(message, form, submitter) {
  const option = (name) =>
    submitter?.getAttribute?.(`data-turbo-confirm-${name}`) ?? form?.getAttribute?.(`data-turbo-confirm-${name}`)

  const dialog = build()
  const id = `unmagic_confirm_${++sequence}`
  const title = dialog.querySelector("[data-unmagic-confirm-title]")
  const body = dialog.querySelector("[data-unmagic-confirm-message]")
  const accept = dialog.querySelector("[data-unmagic-confirm-accept]")
  const cancel = dialog.querySelector("[data-unmagic-confirm-cancel]")

  title.id = `${id}_title`
  body.id = `${id}_message`
  dialog.setAttribute("aria-labelledby", title.id)
  dialog.setAttribute("aria-describedby", body.id)

  body.textContent = message
  if (option("title")) title.textContent = option("title")
  if (option("accept")) accept.textContent = option("accept")

  // A destructive action shouldn't be one Enter away.
  if (option("variant") === "danger") {
    accept.classList.replace("UnmagicButton--primary", "UnmagicButton--danger")
    cancel.autofocus = true
  } else {
    accept.autofocus = true
  }

  document.body.append(dialog)
  dialog.showModal()

  return new Promise((resolve) => {
    dialog.addEventListener(
      "close",
      () => {
        resolve(dialog.returnValue === "confirm")
        dialog.remove()
      },
      { once: true },
    )
  })
}

function build() {
  const template = document.querySelector("template[data-unmagic-confirm]") ?? fallbackTemplate()
  return template.content.firstElementChild.cloneNode(true)
}

let fallback
function fallbackTemplate() {
  if (!fallback) {
    fallback = document.createElement("template")
    fallback.innerHTML = FALLBACK.trim()
  }
  return fallback
}

if (Turbo.config?.forms) {
  Turbo.config.forms.confirm = confirm
} else {
  Turbo.setConfirmMethod(confirm)
}
