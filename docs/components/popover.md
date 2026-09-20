# `popover`

> Status: built
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Popover" (gap source). Sits between
> `tooltip` (text only, on hover) and `menu` (actions only). Depends on
> [position.md](position.md): the shared `position.js` placement, and `menu`
> already on the Popover API.

## Purpose

A panel of rich content anchored to a button: a short form (rename, pick a
date range), a user's profile card, an explanation with a link in it. It opens
on click, stays open while it's used, and closes on an outside click or Escape.

Not for:
- a list of actions: use `menu`
- a one-line hint: use `tooltip`
- anything that should block the page: use `dialog_tag`

## API

```erb
<%= popover "Rename" do |popover| %>
  <%= form_with model: @job, builder: Unmagic::Components::FormBuilder do |form| %>
    <%= form.field :name, "Name" %>
    <%= form.submit "Rename" %>
  <% end %>
<% end %>

<%= popover title: "Ada Lovelace", placement: :bottom, align: :start do |popover| %>
  <% popover.trigger do %>
    <%= image_tag ada.avatar_url, alt: "Ada Lovelace" %>
  <% end %>
  <p>Engineer · joined 2021</p>
  <% popover.footer { link_to "View profile", ada } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| label (positional) | string | `nil` | A text trigger with a chevron. Required unless `popover.trigger` is given |
| `title:` | string | `nil` | A heading, and the panel's accessible name |
| `placement:` | `:bottom`, `:top` | `:bottom` | Flips when there isn't room (`position.js`) |
| `align:` | `:start`, `:center`, `:end` | `:start` | Validated |
| `size:` | `:default`, `:wide` | `:default` | 18rem or 28rem |
| `id:` | string | random | Base for the panel and title ids |

- **Builder parts:**
  - `popover.trigger { … }`: the trigger's content. It's wrapped in the
    button, so don't nest a link or another button in it.
  - `popover.footer { … }`
- Neither a label nor a trigger raises `ArgumentError`.
- Other options go on `<unmagic-popover>`.

## Markup

```html
<unmagic-popover class="UnmagicPopover" placement="bottom" align="start">
  <button type="button" class="UnmagicButton UnmagicPopover__trigger"
          popovertarget="unmagic_popover_9f3c_panel"
          aria-controls="unmagic_popover_9f3c_panel">
    Rename <svg class="UnmagicIcon" aria-hidden="true">…</svg>
  </button>
  <div id="unmagic_popover_9f3c_panel" popover="auto" role="dialog"
       aria-labelledby="unmagic_popover_9f3c_title" class="UnmagicPopover__panel">
    <h2 id="unmagic_popover_9f3c_title" class="UnmagicPopover__title">…</h2>
    <div class="UnmagicPopover__body">…</div>
    <div class="UnmagicPopover__footer">…</div>
  </div>
</unmagic-popover>
```

The markup shape is the one [position.md](position.md) gives `menu`: a
`popovertarget` button and a `popover="auto"` sibling panel. The two differ in
the panel's role (`dialog` here, `menu` there) and in what they hold (arbitrary
content here, menu items there). Like `menu`, the server doesn't render
`aria-expanded`; the element sets it on connect.

`popover="auto"` gives, with no script:
- top-layer rendering, so no card, table cell or scrolling drawer body clips
  it
- light dismiss (outside click and Escape)
- one-at-a-time closing of other auto popovers, open menus included
- `popovertarget` wiring, which also exposes the trigger's expanded state to
  assistive technology

Before upgrade the panel is still usable, sitting where the UA's popover styles
put it. Placement is the only thing the element must add, and it comes from
`position.js`.

## Accessibility

- **Role and name:** a non-modal dialog, `role="dialog"`, named by the title
  when there is one. With no title the helper sets `aria-label` from the label
  text.
- **Expanded state:** the trigger's `aria-expanded` is set by the element on
  connect and kept in sync on `toggle`.

| Key | Where | Does |
|---|---|---|
| Enter / Space | trigger | Toggles (native `popovertarget`) |
| Escape | anywhere | Closes (native), and the element returns focus to the trigger |
| Tab | panel | Moves through the content; tabbing out of the last item closes it and focus continues after the trigger |

- **Focus on open:** the first focusable element in the panel, or the panel
  itself (`tabindex="-1"`) when there is none. Focus stays on the trigger for
  pointer opens without an input in the panel.
- **Focus on close:** Escape returns it to the trigger. A light dismiss leaves
  focus where the user clicked.

## Styling

- CSS section **Popovers**:
  - `UnmagicPopover`, `__trigger`, `__panel`, `__title`, `__body`, `__footer`
  - `__panel--wide`
- **The panel follows the `position.js` contract** (see
  [position.md](position.md)):
  - `.UnmagicPopover__panel[data-side] { position: fixed; inset: auto; margin: 0 }`,
    with the host-type reset `.UnmagicTooltip__popup` and
    `.UnmagicMenu__panel` use
  - `white`/`dark:neutral-900`, a `neutral-200`/`dark:neutral-800` border, 0.5rem
    radius and the menu panel's shadow
- **State:** `.UnmagicPopover__panel:popover-open`, and `[data-side="top"|"bottom"]`
  (written by `position.js`) for the entry offset.
- **Motion:** a 120ms fade and a 4px offset via `@starting-style`, switched off
  under reduced motion.
- **Colour:** palette with `dark:` variants only, as the menu panel.

## Small screens

Below 40rem the panel is a sheet along the bottom of the screen (`data-sheet`), full width and rounded on top, rather than anchored to a trigger a thumb is covering.

## Behaviour (JavaScript)

The element is `<unmagic-popover placement align>`.

- **The panel's `toggle` event** is caught in the capture phase on the
  element, because `toggle` doesn't bubble.
  - **On open:**
    - `this.#release = anchor(panel, trigger, { side: placement, align })`
      from `unmagic/components/position`, which places the panel and keeps it
      placed on scroll, resize and content size changes
    - move focus
    - set `aria-expanded`
    - fire `unmagic-popover:open`
  - **On close:** `this.#release?.()`, reset `aria-expanded`, fire
    `unmagic-popover:close`.
- **Tab out:** a `focusout` on the panel whose `relatedTarget` is outside both
  the panel and the trigger calls `hidePopover()`.
- **A form submit inside:** `turbo:submit-end` with `success` closes the panel.

Turbo:
- **`turbo:before-cache`:** `hidePopover()`, so a snapshot never restores it
  open.
- **`turbo:morph`:** if the panel is still open after the morph, re-place it
  (as `menu` does, see position.md). Otherwise sync `aria-expanded`.
- **Snapshot clones:** nothing is generated. Connect syncs `aria-expanded` to
  `:popover-open`.
- **Streamed content:** `popovertarget` needs no setup, and the listeners are on
  the element.
- **Dependencies:** `unmagic/components/position`. Works without Turbo.

## I18n

None. All text comes from the caller.

## Specs

In `spec/unmagic/components/popover_spec.rb`:

- **Label trigger:** `button[popovertarget]` points at
  `[popover=auto][role=dialog]`, with `aria-controls` and the chevron icon, and
  no server-rendered `aria-expanded`.
- **Title:** `title:` renders an `h2` whose id matches the panel's
  `aria-labelledby`. Without it, the panel has `aria-label` from the label.
- **Builder parts:** `popover.trigger` replaces the label, and `popover.footer`
  renders only when given.
- **Ids:** `id:` derives the panel and title ids, and random ids are distinct
  across two popovers.
- **Options:** `placement:`, `align:` and `size:` attributes and classes, with
  `ArgumentError` for unknown values and for no trigger.
- **Passthrough:** `class:` and `data:` land on the element.

## Preview

In the `elements` page:
- a rename form popover
- a profile card popover with a custom trigger
- a popover inside a flush `card` table cell, to show it isn't clipped
- one near the bottom edge, to show the flip

Check by hand:
- keyboard open and close with focus return
- tabbing out closes
- opening one closes another, including an open `menu`
- Back after opening
- dark theme
- reduced motion

## Open questions

- **Hover-to-open (a "hover card")?** The proposal is no. That is `tooltip`'s
  job, and hover-only panels with interactive content are an accessibility
  trap.
