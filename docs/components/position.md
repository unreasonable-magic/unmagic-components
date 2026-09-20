# `position.js` and `menu` on the Popover API

> Status: built
> Tier: 2 (infrastructure)
> Replaces or relates to: `tooltip`, `popover`, `menu`, `context_menu`,
> `combobox`. There is no Rails Blocks gap source: this is groundwork those
> components share.

## Purpose

Two changes that come before `popover`, `context_menu` and `combobox`:

1. **`position.js`**: one shared module that places a floating panel next to
   an anchor. It is extracted from `tooltip.js`'s `#position`, so every
   component that floats something flips, clamps and repositions the same way.
   It is a module, not an element.
2. **`menu` moves from `<details>` to the native Popover API.** Its panel then
   renders in the top layer, so no card, table cell, drawer body or scrolling
   container can clip it. It is placed by `position.js`, and `context_menu` can
   extend it.

The decision to do both is recorded in the principles, under JavaScript:
shared modules that aren't elements, and elements that extend another.

Order of work:
1. `position.js`
2. `tooltip` adopts it, with no markup change
3. `menu` migrates
4. `popover`
5. `context_menu`
6. `combobox`, then `command_palette`

## API

### `position.js`

Imported by pinned name. It isn't part of any helper.

```js
import { place, anchor, placeAt } from "unmagic/components/position"

// One-off placement. Returns the side used: "top" or "bottom".
place(panel, trigger, { side: "bottom", align: "start", gap: 4, margin: 8 })

// Place now and keep it placed while open. Returns release().
const release = anchor(panel, trigger, { side: "bottom", align: "end" })
release()

// Place at a point (context menus). Same flip and clamp.
placeAt(panel, { x: event.clientX, y: event.clientY }, { margin: 8 })
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `side` | `"top"`, `"bottom"` | `"bottom"` | Preferred side; flips when it doesn't fit and the other side does |
| `align` | `"start"`, `"center"`, `"end"` | `"center"` | Cross-axis alignment against the anchor; logical, so it follows `dir="rtl"` |
| `gap` | px | `8` | Distance from the anchor |
| `margin` | px | `8` | Minimum distance from the viewport edge |

- **`floating`** is any element that is `position: fixed` in viewport
  coordinates. In practice that means a `popover` in the top layer, which is
  what all current callers use.
- **`reference`** is an `Element`, or anything with `getBoundingClientRect()`.
  This "virtual anchor" is how `placeAt` works and how `combobox` could anchor
  to a text range.
- **What `place` does:**
  - writes `style.top` and `style.left` in px
  - writes `data-side="top|bottom"` and `data-align`
  - returns the side it used
- **What `anchor` adds:**
  - calls `place` immediately
  - re-places on `scroll` (capture, passive) and `resize`, batched to one
    `requestAnimationFrame`
  - re-places on a `ResizeObserver` over the floating element, so a combobox
    listbox that fills with results keeps its flip right
  - `release()` removes every listener and observer, and is idempotent
- **What stays with callers:** open/close state, focus, events. The module
  never shows or hides anything.

### `menu` (unchanged helper API)

```erb
<%= menu do |menu| %>
  <% menu.link "Edit", edit_job_path(@job) %>
  <% menu.divider %>
  <% menu.button "Delete", job_path(@job), method: :delete, tone: :danger %>
<% end %>
```

- **Unchanged:** the signature (`menu(label = nil, align: :end, **options)`),
  the builder parts (`link`, `button`, `divider`), `tone:`, the I18n key and
  the validation.
- **New:** `id:` in `options`, which already lands on the root element, now also
  derives the panel id (`"#{id}_panel"`). Without it the base is
  `"unmagic_menu_#{SecureRandom.hex(4)}"`, as `tabs.rb` does.

## Markup

### `menu`, after migration

```html
<unmagic-menu class="UnmagicMenu" align="end">
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicMenu__trigger"
          popovertarget="unmagic_menu_9f3c_panel" aria-controls="unmagic_menu_9f3c_panel"
          aria-haspopup="menu" aria-label="More actions" title="More actions">
    <svg class="UnmagicIcon" aria-hidden="true">…ellipsis_vertical…</svg>
  </button>
  <div id="unmagic_menu_9f3c_panel" popover="auto" role="menu"
       class="UnmagicMenu__panel UnmagicMenu__panel--end">
    <a role="menuitem" class="UnmagicMenu__item" href="/jobs/1/edit">Edit</a>
    <hr class="UnmagicMenu__divider" role="separator">
    <form class="UnmagicMenu__form" …>
      <button role="menuitem" class="UnmagicMenu__item UnmagicMenu__item--danger">Delete</button>
    </form>
  </div>
</unmagic-menu>
```

Compared with the `<details>` version:
- **`<summary>` becomes `<button type="button" popovertarget>`.** It keeps
  `UnmagicMenu__trigger` and its button classes, and a text trigger keeps its
  chevron.
- **`details.UnmagicMenu__details` is gone.** The panel is a direct child of
  the element, with `popover="auto"`.
- **`align` becomes an attribute on the element**, which `menu.js` hands to
  `position.js`. The `UnmagicMenu__panel--start|end` classes stay for
  compatibility, but no CSS depends on them.
- **`aria-expanded` is not rendered by the server.** Browsers already expose the
  expanded state of a `popovertarget` invoker, and a server-rendered `"false"`
  would be wrong for a panel opened before upgrade. The element sets it on
  connect and keeps it true to the panel.

**Without JavaScript:** `popovertarget` opens and closes the panel natively,
with light dismiss and Escape. The panel sits where the UA's popover styles put
it (centred in the viewport) until `position.js` places it. That is usable,
where a clipped or dead menu would not be.

## Accessibility

- **Pattern:** [APG Menu Button](https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/),
  the same as today. The trigger has `aria-haspopup="menu"` and
  `aria-controls`, and the panel is `role="menu"` with `menuitem` children.
- **Keyboard:** preserved exactly from `menu.js`:

| Key | Where | Does |
|---|---|---|
| Enter / Space | trigger | Opens (native `popovertarget`) and focuses the first item |
| Arrow Down | closed trigger | Opens and focuses the first item |
| Arrow Down / Up | open menu | Next / previous item, wrapping |
| Home / End | open menu | First / last item |
| Escape | open menu | Closes (native light dismiss), and focus returns to the trigger |
| Tab | open menu | Closes; focus moves on naturally |
| Enter / click | item | Activates it, and the menu closes after the click has done its job |

- **Focus:** only a keyboard open focuses the first item. A pointer open leaves
  focus on the trigger, as today.
- **Escape focus return:** the HTML popover algorithm restores focus to the
  invoker. The element still calls `close({ focus: true })` so that engines
  which don't are covered.
- **Top layer:** a menu opened inside a modal `<dialog>` stacks above it,
  because it was shown later. It is a DOM descendant of the dialog, so it isn't
  made inert.

## Styling

### `position.js` contract

The module has no CSS section of its own. It relies on this contract:

- **A placed panel** is `position: fixed; inset: auto; margin: 0`, applied once
  `[data-side]` is present (the module's first write). Before that, the UA's
  popover defaults apply, which is what gives the no-JS centring.
- **`[data-side]`** is available for an entry offset or arrow, e.g. the
  `@starting-style` offset in `popover.md`.

### Changes to the **Menus** section

- **`.UnmagicMenu`:** drop `position: relative`, and keep
  `display: inline-block`.
- **Remove** `.UnmagicMenu__trigger { list-style: none }` and the
  `::-webkit-details-marker` rule.
- **`.UnmagicMenu__panel`:**
  - drop `position: absolute`, `top: calc(100% + 0.25rem)` and `z-index: 50`
    (the top layer replaces them)
  - add `.UnmagicMenu__panel[data-side] { position: fixed; inset: auto; margin: 0 }`
  - add a host-type reset, like `.UnmagicTooltip__popup`: the panel still
    inherits from where it sits
  - keep the surface, border, radius, shadow and min-width
- **Remove the rules for** `.UnmagicMenu__panel--end { right: 0 }` and
  `--start { left: 0 }`.
- **No fallback for browsers without popover support.** Add
  `@supports not selector(:popover-open) { .UnmagicMenu__panel { display: none } }`,
  so the panel doesn't show permanently. The Popover API is already required
  by `tooltip` and `toasts`, so there is no new floor.
- **Colour:** the menu's existing palette and `dark:` variants. **Motion:** none, as today.

## Small screens

`sheet()` says when a panel should be a sheet along the bottom instead of anchored (below 40rem); menu and popover ask it before anchoring.

## Behaviour (JavaScript)

### `position.js`

- The placement arithmetic is `tooltip.js`'s `#position` unchanged, with the
  cross axis generalised from centre to `start | center | end`.
  - **Vertical:** try the preferred side, flip if it doesn't fit and the other
    side does, otherwise keep the preferred side.
  - **Horizontal:** align, then clamp between `margin` and
    `viewportWidth - width - margin`.
- Measures with `document.documentElement.clientWidth/Height`, so scrollbars
  are excluded, as tooltip does today.
- **No state lives in the module.** `anchor` closes over its own listeners, so
  any number of panels can be open at once.
- **Turbo:** not applicable, because callers release on close and
  `turbo:before-cache` closes them.

### `tooltip` adoption

- `#position` becomes `place(popup, this, { side: placement, align: "center" })`.
- The `scroll`/`resize` bindings become `this.#release = anchor(…)`, called on
  show and released on hide.
- **No markup, CSS or spec change.** It is verified by hand against the
  existing preview.

### `menu.js` after migration

`class UnmagicMenu extends HTMLElement`. The file adds `export { UnmagicMenu }`
beside the guarded `define`, for `context_menu`.

- **Getters:** `trigger` (`:scope > [popovertarget]`), `panel`
  (`:scope > [popover]`), `items` (unchanged selector).
- **Public methods, as extension points for `context_menu`:**
  - `open({ focusFirst })`: `panel.showPopover()`
  - `close({ focus })`: `panel.hidePopover()`, then refocus the trigger if
    asked
  - `place()`: `anchor(panel, trigger, { side: "bottom", align })`
- **`toggle` on the panel** is caught in the capture phase on the element,
  because `toggle` doesn't bubble:
  - **on open:** `place()`, set `aria-expanded="true"`, bind the keydown
    handler on `document`, and focus the first item if opened from the
    keyboard
  - **on close:** `release()`, set `aria-expanded="false"`, unbind
- **Keyboard:** the same `#keydown` as today, with `details.open = true`
  replaced by `open()`. Enter or Space on the trigger sets the
  opened-from-keyboard flag, and the native invoker opens the panel.
- **Removed:** the `pointerdown` outside listener and the Escape listener.
  `popover="auto"` light dismiss does both. The explicit focus return on Escape
  stays.
- **Kept:**
  - the item-click `setTimeout(close)`, which lets `button_to` forms submit
  - closing on Tab
- **One open at a time:** native. Showing an auto popover closes the other
  open auto popovers that aren't its ancestors.

**Turbo:**
- **`turbo:before-cache`:** `close()`, as today.
- **Snapshot clones:** `:popover-open` isn't an attribute, so a snapshot
  restores closed. Connect syncs `aria-expanded` to `false`.
- **`turbo:morph`:** a behaviour change, and an improvement.
  - Today, Idiomorph resets `details[open]`, so a refresh closes an open menu.
  - The popover-open state isn't in the markup, so the menu now stays open
    through a morph. The element re-places it and re-syncs `aria-expanded`.
  - If a morph removes the panel, `disconnectedCallback` releases.
- **Streamed content:** `popovertarget` needs no setup, and the listeners are
  on the element.
- **Dependencies:** `unmagic/components/position`. It doesn't need Turbo.

## I18n

None new. `unmagic.components.menu.label` ("More actions") is unchanged.

## Specs

`position.js` has no specs, because there are no JS tests. It is covered by
hand checks in the preview.

Changes to `spec/unmagic/components/menu_tabs_clipboard_spec.rb`, `#menu`:

- **"renders a details dropdown behind an icon trigger" becomes "renders a
  popover menu behind an icon trigger":**
  - `unmagic-menu.UnmagicMenu > button[popovertarget]` has `type="button"`,
    `aria-haspopup="menu"`, `aria-label="More actions"`, the
    `UnmagicButton UnmagicButton--icon UnmagicMenu__trigger` classes and an
    svg
  - `unmagic-menu > [popover=auto][role=menu].UnmagicMenu__panel`, whose `id`
    equals the trigger's `popovertarget` and `aria-controls`
  - no `details` or `summary`, and no server-rendered `aria-expanded`
- **Text trigger:** the button's text is "Options", and it has no `aria-label`.
- **Alignment:** the element has `align="start"`, and the panel keeps
  `UnmagicMenu__panel--start`.
- **New:** `menu(id: "job_actions")` has root id `job_actions` and panel id
  `job_actions_panel`. Two menus without ids get distinct panel ids.
- **Unchanged:**
  - link and button item examples, since the selectors don't go through
    `details`
  - the `ArgumentError` examples
- **Selectors to update:** `doc.at("summary")` becomes
  `doc.at("button[popovertarget]")`, and `details > .UnmagicMenu__panel` becomes
  `unmagic-menu > .UnmagicMenu__panel`.

## Compatibility

- **Helper and builder API:** unchanged, so views need no edits.
- **Markup:** a breaking change for hosts that styled or scripted
  `.UnmagicMenu__details`, `summary.UnmagicMenu__trigger`, `details[open]` or
  the `toggle` event on `details`.
  - `UnmagicMenu__trigger`, `UnmagicMenu__panel`, `UnmagicMenu__item` and the
    `--start/--end` classes stay.
  - A "Changed" entry goes in `CHANGELOG.md`, and the release is a minor
    version bump.
- **Browser floor:** unchanged, because `tooltip` and `toasts` already need
  the Popover API.

## Preview

On the `elements` page, the existing `menu` section, plus:

- a menu inside a flush `card` table cell, and one inside a `dialog_tag` body
  with `overflow: auto`, to show neither is clipped
- a menu near the bottom of the viewport, to show it flips up (new behaviour)
- the existing tooltips, unchanged after adopting `position.js`

Check by hand:
- keyboard walkthrough per the table above
- Escape returns focus to the trigger
- opening one menu closes another
- `button_to` Delete still submits with its confirm
- Back after opening restores closed
- a `turbo_stream.refresh` while a menu is open keeps it open and placed
- dark theme
- scrolling a container with a menu open keeps the panel attached
- with JS disabled, the menu opens natively, unplaced

## Open questions

- **Left and right sides.** `side` is only `top | bottom`, which covers every
  current caller. Do `sidebar` flyouts or `dock` need `start | end` sides now,
  or later?
- **CSS anchor positioning.** Once `position-anchor`/`position-area` has
  cross-browser support, `position.js` could become a fallback behind
  `@supports`. Is it worth planning the switch now, or only when all target
  browsers ship it?
- **Menu stays open through a morph.** Is that the behaviour we want? The
  alternative is to close on `turbo:morph` for parity with today.
