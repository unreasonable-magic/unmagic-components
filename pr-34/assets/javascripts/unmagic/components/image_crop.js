// <unmagic-image-crop aspect="1" circular> — rendered by `image_crop`.
// Pointer move/resize and numeric keyboard controls use source-image pixels.
// crop() returns a PNG data URL and fires :crop { dataURL, x, y, width, height };
// failures fire :error { error }. Events have the unmagic-image-crop prefix.
class UnmagicImageCrop extends HTMLElement {
  #box = null
  #drag = null
  constructor() {
    super()
    this.addEventListener("load", (event) => { if (event.target === this.#image) this.#reset() }, true)
    this.addEventListener("error", this.#failed, true)
    this.addEventListener("input", this.#input)
    this.addEventListener("pointerdown", this.#down)
    this.addEventListener("pointermove", this.#move)
    this.addEventListener("pointerup", this.#release)
    this.addEventListener("pointercancel", this.#release)
    this.addEventListener("click", (event) => {
      if (event.target.closest("[data-crop-apply]")) this.crop()
      if (event.target.closest("[data-crop-reset]")) this.#reset()
    })
  }
  get #image() { return this.querySelector("img") }
  get #ratio() { return this.hasAttribute("circular") ? 1 : Number(this.getAttribute("aspect")) || null }
  connectedCallback() {
    if (this.#image?.complete) this.#reset()
    document.addEventListener("turbo:before-cache", this.#release)
  }
  disconnectedCallback() {
    this.#release()
    document.removeEventListener("turbo:before-cache", this.#release)
  }
  #reset = () => {
    const img = this.#image
    if (!img?.naturalWidth) return
    const width = Math.min(img.naturalWidth, this.#ratio ? img.naturalHeight * this.#ratio : img.naturalWidth)
    const height = this.#ratio ? width / this.#ratio : img.naturalHeight
    this.#box = { x: (img.naturalWidth - width) / 2, y: (img.naturalHeight - height) / 2, width, height }
    this.querySelectorAll("input, button").forEach(el => { el.disabled = false })
    this.#paint()
  }
  #paint() {
    const b = this.#box, img = this.#image
    const selection = this.querySelector(".UnmagicImageCrop__selection")
    selection.hidden = false
    Object.assign(selection.style, { left: `${b.x / img.naturalWidth * 100}%`, top: `${b.y / img.naturalHeight * 100}%`, width: `${b.width / img.naturalWidth * 100}%`, height: `${b.height / img.naturalHeight * 100}%` })
    this.querySelectorAll("[data-crop-control]").forEach(el => {
      const key = el.dataset.cropControl
      el.value = Math.round(b[key] * 100) / 100
      el.min = key === "width" || key === "height" ? 1 : 0
      el.max = key === "x" ? img.naturalWidth - b.width : key === "y" ? img.naturalHeight - b.height : key === "width" ? img.naturalWidth : img.naturalHeight
    })
    const result = this.querySelector("[data-image-result]")
    if (result) result.value = ""
    this.querySelector("[data-image-status]").textContent = ""
    const preview = this.querySelector("[data-crop-preview]")
    preview.hidden = true
    preview.removeAttribute("src")
  }
  #constrain() {
    const b = this.#box, img = this.#image
    b.width = Math.max(1, Math.min(img.naturalWidth, b.width))
    b.height = Math.max(1, Math.min(img.naturalHeight, b.height))
    if (this.#ratio) {
      b.width = Math.min(b.width, b.height * this.#ratio)
      b.height = b.width / this.#ratio
    }
    b.x = Math.max(0, Math.min(img.naturalWidth - b.width, b.x))
    b.y = Math.max(0, Math.min(img.naturalHeight - b.height, b.y))
    this.#paint()
  }
  #input = (event) => {
    const key = event.target.dataset.cropControl
    if (!key || !this.#box || !Number.isFinite(event.target.valueAsNumber)) return
    this.#box[key] = event.target.valueAsNumber
    if (this.#ratio && key === "width") this.#box.height = this.#box.width / this.#ratio
    if (this.#ratio && key === "height") this.#box.width = this.#box.height * this.#ratio
    this.#constrain()
  }
  #down = (event) => {
    if (!this.#box || event.button !== 0 || !event.target.closest(".UnmagicImageCrop__selection")) return
    event.preventDefault()
    this.#drag = { id: event.pointerId, x: event.clientX, y: event.clientY, box: { ...this.#box }, resize: !!event.target.closest("[data-crop-handle]") }
    this.setPointerCapture(event.pointerId)
  }
  #move = (event) => {
    const d = this.#drag
    if (!d || event.pointerId !== d.id) return
    const rect = this.#image.getBoundingClientRect()
    const dx = (event.clientX - d.x) / rect.width * this.#image.naturalWidth
    const dy = (event.clientY - d.y) / rect.height * this.#image.naturalHeight
    this.#box = { ...d.box }
    if (d.resize) {
      this.#box.width += dx
      this.#box.height = this.#ratio ? this.#box.width / this.#ratio : d.box.height + dy
    } else {
      this.#box.x += dx
      this.#box.y += dy
    }
    this.#constrain()
  }
  #release = () => {
    if (this.#drag && this.hasPointerCapture(this.#drag.id)) this.releasePointerCapture(this.#drag.id)
    this.#drag = null
  }
  #failed = (error) => {
    const status = this.querySelector("[data-image-status]")
    if (status) status.textContent = status.dataset.error
    this.dispatchEvent(new CustomEvent("unmagic-image-crop:error", { bubbles: true, detail: { error } }))
  }
  crop() {
    try {
      if (!this.#box) throw new Error("Image not loaded")
      const b = this.#box
      const canvas = document.createElement("canvas")
      canvas.width = Math.max(1, Math.round(b.width))
      canvas.height = Math.max(1, Math.round(b.height))
      const ctx = canvas.getContext("2d")
      if (this.hasAttribute("circular")) {
        ctx.beginPath()
        ctx.ellipse(canvas.width / 2, canvas.height / 2, canvas.width / 2, canvas.height / 2, 0, 0, Math.PI * 2)
        ctx.clip()
      }
      ctx.drawImage(this.#image, b.x, b.y, b.width, b.height, 0, 0, canvas.width, canvas.height)
      const dataURL = canvas.toDataURL("image/png")
      const preview = this.querySelector("[data-crop-preview]")
      preview.src = dataURL
      preview.hidden = false
      const input = this.querySelector("[data-image-result]")
      if (input) {
        input.value = dataURL
        input.dispatchEvent(new Event("input", { bubbles: true }))
        input.dispatchEvent(new Event("change", { bubbles: true }))
      }
      this.querySelector("[data-image-status]").textContent = `${canvas.width} × ${canvas.height} PNG`
      this.dispatchEvent(new CustomEvent("unmagic-image-crop:crop", { bubbles: true, detail: { dataURL, ...b } }))
      return dataURL
    } catch (error) { this.#failed(error); return null }
  }
}
customElements.get("unmagic-image-crop") || customElements.define("unmagic-image-crop", UnmagicImageCrop)
