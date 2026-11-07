// Browser-only controls. No preview preferences change the browser's global theme.
class BrowserBlockPreview extends HTMLElement {
  connectedCallback() {
    this.addEventListener("click", this.clicked)
  }

  disconnectedCallback() {
    this.removeEventListener("click", this.clicked)
  }

  clicked = (event) => {
    const button = event.target.closest("button")
    if (!button) return
    const frame = this.querySelector("[data-preview-frame]")
    if (button.hasAttribute("data-preview-width")) {
      frame.style.width = button.dataset.previewWidth
      this.querySelectorAll("[data-preview-width]").forEach((control) => {
        control.setAttribute("aria-pressed", String(control === button))
      })
    }
    if (button.hasAttribute("data-preview-theme")) {
      const theme = button.dataset.previewTheme
      const url = new URL(frame.src)
      url.searchParams.set("preview_theme", theme)
      frame.src = url.href
      this.querySelector("[data-preview-open]").href = url.href
      this.querySelectorAll("[data-preview-theme]").forEach((control) => {
        control.setAttribute("aria-pressed", String(control === button))
      })
    }
    if (button.hasAttribute("data-preview-reload")) frame.src = frame.src
    const size = this.querySelector('[data-preview-width][aria-pressed="true"]').getAttribute("aria-label")
    const theme = this.querySelector('[data-preview-theme][aria-pressed="true"]').textContent
    this.querySelector("[data-preview-status]").textContent = `${size} · ${theme}`
  }
}

if (!customElements.get("browser-block-preview")) customElements.define("browser-block-preview", BrowserBlockPreview)

// Example forms validate locally and explain that no data is saved or sent.
document.addEventListener("submit", (event) => {
  if (!event.target.matches("[data-block-demo-form]")) return
  event.preventDefault()
  event.target.querySelector("[data-block-demo-status]").textContent =
    event.target.dataset.blockDemoMessage ||
    "This is a preview. Connect this form to your authentication endpoint in your app."
})


// Reset native fields and any feedback from the preceding demo submission.
document.addEventListener("reset", (event) => {
  if (event.target.matches("[data-block-demo-form]")) {
    event.target.querySelector("[data-block-demo-status]").textContent = ""
  }
})
