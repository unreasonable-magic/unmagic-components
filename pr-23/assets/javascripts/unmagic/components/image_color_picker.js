// <unmagic-image-color-picker input="field_id"> — rendered by `image_color_picker`.
// Extracted from Toybox's offer preview: map the displayed image to source pixels,
// write a hex value and notify the form. Canvas sampling works without EyeDropper
// or a screenshot polyfill. Arrow keys move, Shift moves ten pixels, Enter picks.
// Fires unmagic-image-color-picker:change { value, x, y } or :error { error }.
class UnmagicImageColorPicker extends HTMLElement {
  #x = 0.5
  #y = 0.5
  constructor() {
    super()
    this.addEventListener("click", this.#pick)
    this.addEventListener("keydown", this.#key)
  }
  #key = (event) => {
    const img = this.querySelector("img")
    const directions = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }
    const delta = directions[event.key]
    if (!delta || !img.naturalWidth) return
    event.preventDefault()
    const step = event.shiftKey ? 10 : 1
    this.#x = Math.max(0, Math.min(1, this.#x + delta[0] * step / img.naturalWidth))
    this.#y = Math.max(0, Math.min(1, this.#y + delta[1] * step / img.naturalHeight))
    this.#cursor()
  }
  #cursor() {
    const cursor = this.querySelector(".UnmagicImageColorPicker__cursor")
    cursor.style.left = `${this.#x * 100}%`
    cursor.style.top = `${this.#y * 100}%`
  }
  #pick = (event) => {
    if (!event.target.closest("button")) return
    const img = this.querySelector("img")
    const status = this.querySelector("[data-image-status]")
    try {
      const field = document.getElementById(this.getAttribute("input"))
      if (!field || field.disabled || field.readOnly || !img.naturalWidth) throw new Error("Image or target field unavailable")
      if (event.detail) {
        const rect = img.getBoundingClientRect()
        this.#x = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
        this.#y = Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height))
      }
      this.#cursor()
      const x = Math.min(img.naturalWidth - 1, Math.floor(this.#x * img.naturalWidth))
      const y = Math.min(img.naturalHeight - 1, Math.floor(this.#y * img.naturalHeight))
      const canvas = document.createElement("canvas")
      canvas.width = canvas.height = 1
      const context = canvas.getContext("2d")
      context.drawImage(img, x, y, 1, 1, 0, 0, 1, 1)
      const rgb = context.getImageData(0, 0, 1, 1).data.slice(0, 3)
      const value = `#${Array.from(rgb, c => c.toString(16).padStart(2, "0")).join("")}`
      field.value = value
      field.dispatchEvent(new Event("input", { bubbles: true }))
      field.dispatchEvent(new Event("change", { bubbles: true }))
      status.textContent = value
      this.dispatchEvent(new CustomEvent("unmagic-image-color-picker:change", { bubbles: true, detail: { value, x, y } }))
    } catch (error) {
      status.textContent = status.dataset.error
      this.dispatchEvent(new CustomEvent("unmagic-image-color-picker:error", { bubbles: true, detail: { error } }))
    }
  }
}
customElements.get("unmagic-image-color-picker") || customElements.define("unmagic-image-color-picker", UnmagicImageColorPicker)
