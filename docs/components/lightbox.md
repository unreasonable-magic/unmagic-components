# `lightbox_link_to` / `lightbox_dialog`

> Status: draft
> Tier: 3 (large)
> Replaces or relates to:
> - Rails Blocks "Lightbox" (the gap source)
> - `dialog.js` (open/close delegation, backdrop, cache close), `dialog_tag`, `confirm_dialog_template` (render-once-in-layout pattern), `carousel`

## Purpose

Opens a full-size image over the page when a thumbnail is clicked, and steps
through the other images in the same gallery. Examples: attachments on an
issue, screenshots in a bug report, product photos in an admin.

It is **not** for arbitrary content in a dialog (use `dialog_tag`) or for
video. Without JavaScript the thumbnail is a normal link to the full image.

## API

```erb
<%# Once, in the layout %>
<%= lightbox_dialog %>

<% @attachments.each do |attachment| %>
  <%= lightbox_link_to url_for(attachment.file), gallery: dom_id(@issue, :attachments),
        caption: attachment.filename, srcset: attachment.srcset do %>
    <%= image_tag attachment.thumbnail, alt: attachment.description %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `gallery:` | string | nil | Links sharing it step together. nil means a single image |
| `caption:` | string | nil | Shown under the image, and becomes the dialog's name |
| `alt:` | string | the thumbnail `<img>`'s `alt` | The full image's `alt`; blank means decorative |
| `srcset:`, `sizes:` | strings | nil | Passed to the full image |

- The first argument is the full image URL, used for both `href` and `src`.
- The block is the thumbnail. Other options go on the `<a>`.
- A blank URL raises `ArgumentError`.
- `lightbox_dialog(id: "unmagic_lightbox")`. The id rarely changes, but it's
  configurable like `modal_frame_id`.

## Markup

```html
<a href="/files/12.png" class="UnmagicLightboxLink" data-unmagic-lightbox="issue_7_attachments"
   data-unmagic-lightbox-caption="error.png" data-unmagic-lightbox-srcset="…">
  <img src="/files/12-thumb.png" alt="Stack trace of the 500 error">
</a>

<dialog id="unmagic_lightbox" class="UnmagicLightbox" data-unmagic-dialog data-turbo-permanent
        aria-labelledby="unmagic_lightbox_caption">
  <div class="UnmagicLightbox__stage">
    <img class="UnmagicLightbox__image" alt="">
    <span class="UnmagicLightbox__loading" hidden><!-- spinner --></span>
  </div>
  <p class="UnmagicLightbox__caption" id="unmagic_lightbox_caption"></p>
  <p class="UnmagicLightbox__counter" aria-live="polite"></p>
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicLightbox__prev" aria-label="Previous image">…</button>
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicLightbox__next" aria-label="Next image">…</button>
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicLightbox__close" aria-label="Close" data-unmagic-dialog-close>…</button>
</dialog>
```

- **Native base:** a modal `<dialog>` gives the top layer, focus containment,
  Escape and the backdrop.
- **Reused from `dialog.js`:** `data-unmagic-dialog` gives backdrop-click
  close, `data-unmagic-dialog-close` the close button, and the
  close-before-cache handling.
- **Server-rendered chrome:** the layout renders the chrome once, so labels are
  translated server-side (the `confirm_dialog_template` pattern).
- **Without `lightbox_dialog`:** clicks follow the link.

## Accessibility

- **Pattern:** APG Dialog (Modal). The dialog is named by the caption, or by
  "Image" from I18n when there is no caption.
- **The full image** gets the thumbnail's `alt`, or the `alt:` option.
- **The counter** ("2 of 7") is a polite live region, updated on each step.
- **Keyboard:**

| Key | Does |
|---|---|
| Enter on a thumbnail link | Opens the lightbox at that image |
| Arrow Left / Right | Previous / next image in the gallery (no wrap) |
| Home / End | First / last image |
| Tab | Cycles prev, next and close inside the dialog (native modal containment) |
| Escape | Closes it (native) |

- **Focus:**
  - On open, focus goes to the close button.
  - On close, focus returns to the link that opened it. That is set
    explicitly, because Safari doesn't focus links on click.
  - If that link is gone (streamed away), focus returns to the gallery's first
    remaining link.
- **Edges and single images:** prev and next get `aria-disabled` at the edges,
  and are `hidden` for a single image.

## Styling

- **CSS section `Lightbox`.** Elements: `__stage`, `__image`, `__loading`,
  `__caption`, `__counter`, `__prev`, `__next`, `__close`, plus
  `UnmagicLightboxLink` (`cursor: zoom-in`, `display: inline-block`, focus
  outline).
- **The dialog:**
  - `width: 100vw; height: 100dvh; max-width: none; max-height: none`
  - `::backdrop` at `black/50`/`dark:black/60`, the same colour dialogs use
  - its own background is also `black/50`/`dark:black/60`
- **The image:** `max-width: min(100%, 90vw); max-height: 80dvh;
  object-fit: contain`, centred in a grid.
- **Controls:** fixed to the viewport edges, with a caption and counter
  underneath.
- **No new colours (decided).**
  - The backdrop reuses the dialogs' `black/50`/`dark:black/60`.
  - A dialog's own backdrop is too thin to view an image against. The
    full-viewport lightbox therefore paints it twice, once on `::backdrop` and
    once as the dialog's background, for roughly 75% dimming (84% in dark).
  - If the dialogs' backdrop changes, the lightbox follows it.
  - The on-dark text and icon colours are `white` in both themes.
- **State:**
  - `[data-loading] .UnmagicLightbox__loading` shows the spinner.
  - `.UnmagicLightbox__image[data-ready]` fades in over 150ms, which is off
    under reduced motion.

## Behaviour (JavaScript)

`lightbox.js` has no custom element. It uses document-level delegation like
`dialog.js`, guarded by `Symbol.for("unmagic-components.lightbox")`, and
imports `"unmagic/components/dialog"`.

- **Opening:**
  - A `click` on `a[data-unmagic-lightbox]` with no modifier keys and a primary
    button calls `preventDefault()`.
  - It looks up `#unmagic_lightbox`. If the dialog is missing, the click falls
    through to the link.
  - It collects the gallery at that moment: every `a[data-unmagic-lightbox="<same>"]`
    in document order, so streamed-in thumbnails join it.
  - Then it runs `show(index)` and `showModal()`.
- **`show(index)`:**
  - sets `data-loading` and the image's `src`, `srcset`, `sizes` and `alt`
  - on `load`, removes `data-loading` and sets `data-ready`
  - on `error`, shows "Couldn't load image" in the caption
  - updates the caption, the counter and the edge states
  - preloads the neighbours with `new Image()`
  - fires `unmagic-lightbox:show` with `{ index, href }` on the dialog
- **Keys:** Arrow, Home and End are handled on the dialog while it's open.
  Touch swipe handling (pointer events, a horizontal delta over 50px) is
  optional in v1 (see the open questions).
- **Close:** it listens for the dialog's `close` event. It clears `src`, so a
  large image stops downloading, and restores focus to the opener.

Turbo:
- **Cache:** `dialog.js` already closes open `dialog[data-unmagic-dialog]`
  before caching. The `close` handler clears the image, so the snapshot holds
  empty chrome.
- **Permanent:** `data-turbo-permanent` keeps the one dialog across visits, so
  a visit or morph doesn't re-render it while it's open. That is safe because
  its content is set entirely by script.
- **Morph:** being permanent, Idiomorph leaves the dialog alone, so a
  live-updating page doesn't close the viewer. Morphed thumbnails are picked up
  on the next open, because the gallery is gathered at click time.
- **Snapshot clones:** a restored snapshot contains the closed, cleared dialog,
  with nothing generated.
- **Streamed content:** new thumbnail links need no setup (delegation). If the
  opener is removed while the lightbox is open, the stored gallery array still
  navigates, and focus falls back as described above.

Dependencies: `dialog.js`. It doesn't need Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.lightbox.label` | "Image" |
| `unmagic.components.lightbox.previous` | "Previous image" |
| `unmagic.components.lightbox.next` | "Next image" |
| `unmagic.components.lightbox.counter` | "%{number} of %{count}" |
| `unmagic.components.lightbox.error` | "Couldn't load image" |
| `unmagic.components.dialog.close` | "Close" (reused) |

## Specs

In `dialog_spec.rb`, or a new `lightbox_spec.rb`:
- `lightbox_link_to` renders `a.UnmagicLightboxLink[href]`, with the
  `data-unmagic-lightbox` gallery, caption, srcset and sizes, wrapping the
  block.
- `gallery: nil` renders an empty `data-unmagic-lightbox`.
- `class:` and attributes pass through. A blank URL raises `ArgumentError`.
- `lightbox_dialog` renders `dialog#unmagic_lightbox[data-unmagic-dialog][data-turbo-permanent]`
  with an image, caption, counter, and prev, next and close buttons with
  labels.
- The close button carries `data-unmagic-dialog-close`, and the dialog carries
  `aria-labelledby` pointing at the caption id.
- A custom `id:` is honoured.

## Preview

On `dialogs`: a grid of 6 thumbnails in one gallery, and one standalone image.
The preview layout gains `lightbox_dialog`.

Hand checks:
- Click, then arrows through the gallery, and Home/End.
- Escape, a backdrop click and the close button each close it, and focus
  returns to the thumbnail.
- Cmd/Ctrl-click opens the image in a new tab.
- A slow image (throttle) shows the spinner.
- A broken URL shows the error.
- VoiceOver reads the caption and "2 of 6".
- Back after opening: the snapshot is closed.
- Reduced motion.
- Dark mode, where the doubled `dark:black/60` backdrop should dim the page
  enough to view a light image.

## Open questions

- **Zoom:** should pinch or click to zoom and pan the full image be in scope?
  Proposed: native pinch only.
- **Swipe:** should touch swipe between images be in v1?
- **One dialog:** should galleries share one layout dialog (proposed), or
  should `lightbox_dialog` be optional, with the script creating chrome in
  English when it's absent (as `confirm.js` does)?
