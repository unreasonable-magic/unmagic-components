// A toggle button with no name flips its own aria-pressed on click, rendered by
// `toggle` without name:. One with a name is a checkbox and needs nothing.
// Each flip fires unmagic-toggle:change with { pressed }.

document.addEventListener("click", (event) => {
  const button = event.target instanceof Element && event.target.closest("button.UnmagicToggle[aria-pressed]")
  if (!button || button.disabled) return

  const pressed = button.getAttribute("aria-pressed") !== "true"
  button.setAttribute("aria-pressed", String(pressed))
  button.dispatchEvent(new CustomEvent("unmagic-toggle:change", { bubbles: true, detail: { pressed } }))
})
