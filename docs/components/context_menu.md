# `context_menu`

> Status: built
> Tier: 2 (small element)
> Replaces or relates to:
> - Rails Blocks "Context Menu" (the gap source)
> - Builds on `menu` after its migration to the Popover API:
>   `menu.rb`'s builder and `menu.js`'s `UnmagicMenu`, extended through
>   `export`. Placement comes from `position.js`. See
>   [position.md](position.md).

## Purpose

Opens a menu of actions at the pointer when the reader right-clicks something,
long-presses it on touch, or presses the context-menu key while it has focus.
It gives power users a quick path to the row actions of a table or the items of
a file list.

It is **never the only way to reach an action.** Context menus can't be
discovered, so every item must also be reachable from something visible,
normally a `menu` in the row. That is why the API takes the same items as
`menu`.

## API

```erb
<%= table_for @files, row_id: ->(file) { dom_id(file) } do |table| %>
  <% table.column "Name" do |file| %>
    <%= file.name %>
    <%= context_menu for: dom_id(file) do |menu| %>
      <% menu.link "Open", file_path(file) %>
      <% menu.divider %>
      <% menu.button "Delete", file_path(file), method: :delete, tone: :danger %>
    <% end %>
  <% end %>
<% end %>

<%# One set of items for both the visible menu and the context menu %>
<% items = ->(menu) { menu.link "Open", file_path(file); menu.button "Delete", … } %>
<%= menu(&items) %>
<%= context_menu for: dom_id(file), &items %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `for:` | an element id | required | The region that opens it; any element, even a `<tr>` |
| `label:` | string | "Actions" (I18n) | The menu's accessible name |
| `id:` | string | random | Base for the panel id, as in `menu` |

- **The builder is `Components::Menu`:** `link`, `button` and `divider`, with
  `tone: :danger`, all unchanged.
- **`align:` isn't accepted:** it has no meaning, because the menu is placed at
  the pointer.
- **Other options go on the element.** No items renders nothing.

## Markup

The Ruby side renders through `Menu` with a new internal mode, `context:`. It
emits the same popover panel and items as the migrated `menu`, without a
trigger button:

```html
<unmagic-context-menu class="UnmagicMenu UnmagicMenu--context" for="file_12">
  <div id="unmagic_menu_4b1e_panel" popover="auto" role="menu" aria-label="Actions"
       class="UnmagicMenu__panel">
    <a role="menuitem" class="UnmagicMenu__item" href="/files/12">Open</a>
    <hr class="UnmagicMenu__divider" role="separator">
    <form class="UnmagicMenu__form" …><button role="menuitem" class="UnmagicMenu__item UnmagicMenu__item--danger">Delete</button></form>
  </div>
</unmagic-context-menu>
```

- **Reuse:** the popover's open state is the menu's state, so every close path
  `UnmagicMenu` has works unchanged:
  - light dismiss (an outside press, or Escape)
  - choosing an item
  - Tab
  - `turbo:before-cache`
- **Placement:** the element can sit anywhere in the DOM, in a cell or after the
  table. It doesn't have to wrap the region, because a table row can't be
  wrapped. The panel is in the top layer, so where it sits never clips it.
- **Without JavaScript:** nothing opens, and the native context menu shows.
  That is safe, because the items are reachable elsewhere.

## Accessibility

- **Pattern:** APG Menu, the same as `menu`. The panel is `role="menu"`, named
  by `aria-label`.
- **Keyboard:**

| Key | Where | Does |
|---|---|---|
| Shift+F10, or the ContextMenu key | focused region, or anything focusable inside it | Opens at the region's top-left and focuses the first item |
| Arrow Down / Up, Home, End | open menu | Moves between items (inherited) |
| Enter / Space | item | Activates it and closes |
| Escape | open menu | Closes, and returns focus to the element focused before opening |
| Tab | open menu | Closes (inherited) |

- **Focus:** a keyboard open always focuses the first item. A pointer open
  focuses the panel, so the arrow keys work straight away.
- **Focusable regions:** keyboard users need the region to be focusable. When
  `for:` names a non-focusable element, script does **not** add `tabindex`,
  because that would put every row in the tab order. Shift+F10 still works from
  a focused link or button inside the region, since `contextmenu` bubbles.
- **Discoverability:** script sets `aria-keyshortcuts="Shift+F10"` on the
  region.

## Styling

- **CSS:** it reuses the **Menus** section as migrated in position.md. Its
  panel is already a fixed, top-layer popover placed through `[data-side]`.
  The only addition:
  - `UnmagicMenu--context`: `display: contents`, so the host element takes no
    space
- **The panel keeps the menu's look:** surface, border, radius, shadow and
  min-width.
- **Colour:** the menu's palette and `dark:` variants. **Motion:** none, as for `menu`.

## Small screens

A long press (500ms) on a touch screen opens it where a right-click would; the panel is then a bottom sheet with taller items.

## Behaviour (JavaScript)

`context_menu.js` defines `<unmagic-context-menu>` as
`class UnmagicContextMenu extends UnmagicMenu`, imported with
`import { UnmagicMenu } from "unmagic/components/menu"`. The principles allow
an element that extends another, and the migrated `menu.js` exports
`UnmagicMenu`.

What it overrides or adds:
- **`trigger`:** returns `null`. There is no invoker, so `open()` calls
  `showPopover()` directly.
- **`place()`:** `placeAt(panel, this.#point, { margin: 8 })` from
  `unmagic/components/position`, instead of anchoring to a trigger. A keyboard
  open passes the region itself as the reference, so the menu is placed against
  its bounding box.
- **`close({ focus })`:** returns focus to the element that was focused before
  opening, not to a trigger.
- **Opening on `contextmenu`:** on `document`, delegated to the region
  (`event.target.closest("#" + for)`).
  - Calls `preventDefault`, records the pointer point, then `open()`.
  - A keyboard-generated event (`clientX`/`clientY` of 0, or `detail === 0`)
    opens against the region and focuses the first item.
  - **Shift+right-click is left alone**, so the browser menu stays reachable
    for copying links and text.
- **Long press on touch:**
  - `pointerdown` with `pointerType === "touch"` starts a 500ms timer.
  - Moving more than 10px, `pointerup` or `pointercancel` cancels it.
  - When it fires, the menu opens at the touch point and the `click` that
    follows is suppressed.
  - iOS Safari doesn't fire `contextmenu`, so this is needed.
- **Scroll:** closes on scroll, because a point anchor would drift. See Open
  questions.
- **Only one open at a time:** native. Showing an auto popover closes any other
  open `menu`, `context_menu` or `popover`.
- **Events:** `unmagic-context-menu:open`, with `{ region }`.

Turbo:
- **Cache:** it inherits `close()` on `turbo:before-cache` from `UnmagicMenu`.
- **Snapshot clones:** there is no generated DOM. `:popover-open` isn't
  serialised, and the placement styles are rewritten on the next open.
- **Morph:** inherited. The popover-open state survives a morph. A context menu
  re-places at its recorded point, or closes if its region is gone.
- **Streamed content:** the `contextmenu` listener sits on `document` and looks
  up the region by id when the event fires, so regions and menus streamed in
  later work with no setup.
  - The listener is added in `connectedCallback` and removed in
    `disconnectedCallback`, once per menu. That is cheap for dozens of rows.
  - If benchmarks disagree, switch to a single delegated listener
    (`dialog.js` style).

Dependencies: `menu.js` and `position.js`. It doesn't need Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.context_menu.label` | "Actions" |

## Specs

In `menu_tabs_clipboard_spec.rb` or a new `context_menu_spec.rb`:
- **Structure:** renders `unmagic-context-menu[for=file_12]` whose direct child
  is `[popover=auto][role=menu].UnmagicMenu__panel`, with `aria-label`. There is
  no `button[popovertarget]`.
- **Items:** `link`, `button` and `divider` render exactly as in `menu`,
  including `--danger`.
- **Ids:** `id:` derives the panel id, and random ids are distinct.
- **Errors:** a missing `for:` raises `ArgumentError`, as does passing `align:`.
- **Empty:** no items renders an empty string.
- **Passthrough:** `class:` and attributes pass through.
- **Regression:** `menu`'s own output matches the migrated markup in
  position.md.

## Preview

On `elements`: a table of files, where each row has a ⋮ `menu` and a
`context_menu` built from the same lambda.

Hand checks:
- **Pointer:** right-click a row; the menu opens at the pointer and is clamped
  in the corners of the window.
- **Browser menu:** Shift+right-click shows the browser's menu.
- **Touch:** long press in touch emulation.
- **Keyboard:** tab to a row's link and press Shift+F10; the first item is
  focused, and Escape returns focus to the link.
- **Forms:** the `button_to` Delete submits with its confirm.
- **One at a time:** opening the row's ⋮ menu closes an open context menu.
- **Turbo:** Back leaves no menu open.
- **Theme:** check dark mode.

## Open questions

- **Items lambda:** should the builder accept a shared items proc officially
  (`menu items: …`), rather than relying on `&block` reuse?
- **Plain regions:** should a region that isn't focusable get
  `tabindex="-1"` and a roving pattern for tables? That belongs to a future
  table-grid note, not here.
- **Scroll:** should the menu close on scroll, as proposed, or follow the
  region?
