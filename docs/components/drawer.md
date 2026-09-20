# Drawers: `side:` on `dialog`, `dialog_tag` and `modal_link_to`

> Status: built
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Drawer" and "Slideover" (gap source).
> Extends `Dialog`, `dialog_tag`, `modal_frame`, `dialog.js` and `modal.js`; no
> new system.

## Purpose

A panel that slides in from the edge of the screen, for work that wants more
height than a centred dialog but shouldn't leave the page: filters, a record's
details beside its list, a long settings form.

A drawer **is** a modal `<dialog>`, positioned differently, so it gets
everything the dialogs already do:
- Escape and backdrop close
- the Turbo Frame loading skeleton
- the error panel with retry
- the save that closes in the same render as the refresh

It is not a persistent sidebar. For app navigation see `sidebar.md`.

## API

```erb
<%# Same-page drawer %>
<%= dialog_button "Filters", dialog: "job_filters", class: button_classes %>
<%= dialog_tag "job_filters", title: "Filters", side: :end do |dialog| %>
  …
  <% dialog.footer { tag.button "Apply", class: button_classes(:primary) } %>
<% end %>

<%# Server-loaded drawer through the shared modal %>
<%= modal_link_to "Details", job_path(job), side: :end %>

<%# jobs/show.html.erb: the response says where it belongs too %>
<%= dialog title: @job.name, side: :end do %> … <% end %>
```

| Option | On | Values | Default | Notes |
|---|---|---|---|---|
| `side:` | `dialog`, `dialog_tag`, `modal_link_to` | `:center`, `:start`, `:end` | `:center` | Validated. `:start`/`:end` are logical, so they flip in RTL |
| `size:` | `dialog`, `dialog_tag` | `:default`, `:wide` | `:default` | A drawer is 28rem, or 40rem wide |

- `Dialog::SIDES = %i[center start end].freeze`, validated alongside `SIZES`.
- `modal_link_to … side:` adds `data-unmagic-modal-side="end"` to the link. It
  is the only way the skeleton can open in the right place before the response
  arrives.
- The panel's own `side:` wins once the response loads, so visiting a URL
  directly (no link) still lands correctly.

## Markup

`dialog_tag` with `side: :end`:

```html
<dialog id="job_filters" class="UnmagicDialogBox" data-side="end"
        data-unmagic-dialog aria-labelledby="unmagic_dialog_1a2b_title">
  <div class="UnmagicDialog UnmagicDialog--drawer">
    <header class="UnmagicDialog__header">
      <h2 id="unmagic_dialog_1a2b_title" class="UnmagicDialog__title">Filters</h2>
      <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicDialog__close"
              aria-label="Close" data-unmagic-dialog-close>…</button>
    </header>
    <div class="UnmagicDialog__body">…</div>
    <div class="UnmagicDialog__footer">…</div>
  </div>
</dialog>
```

- `dialog side: :end` renders the panel with `data-side="end"`, so `modal.js`
  can read it.
- The box position is an attribute (`data-side`), not a class. The shared
  modal's box changes side from one load to the next, and script sets an
  attribute cleanly.

## Accessibility

- The [APG dialog (modal)](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
  pattern, unchanged. It is a native `showModal()` dialog, so focus is trapped,
  the page behind is inert, and focus returns to the opener on close.
- The name comes from `aria-labelledby` on the title, as today. `modal.js`'s
  `#label` already handles the shared modal.

| Key | Does |
|---|---|
| Escape | Closes (native) |
| Tab / Shift+Tab | Cycles within the drawer (native modal) |

## Styling

Added to the existing **Dialogs** section:

- `.UnmagicDialogBox[data-side="start"|"end"]`:
  - `margin: 0`
  - `inset-block: 0`, `inset-inline-start: 0` (or `-end`)
  - `height: 100dvh`, `max-height: 100dvh`
  - `max-width: calc(100vw - 3rem)`
- `.UnmagicDialog--drawer`:
  - `width: min(100vw - 3rem, 28rem)`, or 40rem with `--wide`
  - `height: 100%`, `display: flex; flex-direction: column`
  - square outer corners, a border only on the inner edge
- `.UnmagicDialog--drawer .UnmagicDialog__body`: `flex: 1; overflow-y: auto`.
  The footer stays pinned.
  - **Trade-off:** a centred dialog keeps `overflow: visible` so a `menu`
    inside isn't clipped; a drawer body scrolls, so a `<details>` menu inside
    it can be clipped. `popover.md`'s top-layer panel avoids this. Flag this in
    the README.
- Motion: `@keyframes unmagic-drawer-in-end` slides in from
  `translateX(100%)` (mirrored for `start`, and flipped under
  `:dir(rtl)`) over 200ms. It is switched off under reduced motion, like
  `unmagic-dialog-in`.
- Colours: `white`/`dark:neutral-900`, `neutral-200`/`dark:neutral-800`, and the
  dialogs' `black/50`/`dark:black/60` backdrop.

## Small screens

Below 40rem a drawer is the same bottom sheet every dialog becomes: full width, rounded on top, its body scrolling and its footer above the home indicator.

## Behaviour (JavaScript)

`dialog_tag` drawers need **nothing new**: `dialog.js` already opens them,
closes them and handles `turbo:before-cache` by delegation.

`modal.js` gains:

- **A delegated `click` listener (capture phase) on `document`** for
  `a[data-turbo-frame=<modal id>]`. It remembers the link's
  `data-unmagic-modal-side`, or `center`, for the next load of its own frame.
- **`#loading`**, when the skeleton is filled, sets `data-side` on the dialog
  box from what was remembered. The skeleton panel gets `UnmagicDialog--drawer`
  when the side isn't `center`.
- **`#loaded`** reads `data-side` from the loaded panel
  (`.UnmagicDialog[data-side]`). If it's present and differs, it updates the
  box. A mid-open change of side snaps rather than animates.
- **`#reset`** (on close) removes `data-side`, so the next plain modal link
  opens centred.

Turbo:

- **`turbo:before-cache`**: open dialogs are already closed by `dialog.js`, and
  the reset clears `data-side`.
- **`turbo:morph`**: a drawer that stays open across a refresh keeps its box
  attributes. Morph leaves the `unmagic-modal` subtree's attributes alone
  because the server renders none on the box.
- **Snapshot clones**: nothing generated.
- **Streamed content**: a panel streamed into the frame is read by `#loaded`.
- **Dependencies:** `modal.js` needs Turbo, as today. `dialog_tag` drawers
  don't.

## I18n

None new. The close label is `unmagic.components.dialog.close`.

## Specs

In `spec/unmagic/components/dialog_spec.rb`:

- `dialog_tag side: :end` puts `data-side="end"` on the `<dialog>` and
  `UnmagicDialog--drawer` on the panel.
- `dialog side: :start` renders `data-side` on the panel, including inside the
  modal frame request (`build_view(turbo_frame: "modal")`).
- `modal_link_to side: :end` adds `data-unmagic-modal-side` and keeps
  `data-turbo-frame`, in both block and non-block forms.
- `side: :center` (the default) renders no `data-side` and no drawer class, so
  existing markup is unchanged.
- An unknown `side:` raises `ArgumentError` from `dialog`, `dialog_tag` and
  `modal_link_to`.

## Preview

On the `dialogs` page:
- a same-page filters drawer (`:end`)
- a `:start` navigation-style drawer
- a modal link that opens the profile form as a drawer, including the slow and
  forbidden routes

Check by hand:
- the skeleton appears on the correct side
- the save closes it in the refresh render
- Escape and backdrop close it
- a long body scrolls with the footer pinned
- RTL (`dir="rtl"` on `<html>`)
- reduced motion
- dark theme

## Open questions

- **`:bottom`** (a mobile sheet). It's a common pattern; add it now or later?
- Should `side:` on the link be required for the skeleton, or should the modal
  learn the side from the response only (a centred skeleton, then a jump)? The
  proposal is the link attribute: no jump, and a tiny, explicit API.
- Is capturing the click the right way to learn which link opened the frame?
  The alternative is reading `turbo:before-fetch-request`'s initiator, but
  Turbo doesn't expose it for frames today.
