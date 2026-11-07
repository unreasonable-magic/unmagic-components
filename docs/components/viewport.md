# `viewport_tag`

> Status: draft (built ahead of review, against iOS 27 Safari in the simulator)
> Tier: 2 (small element)
> Replaces or relates to: the `ai_chat` composer and transcript it keeps on screen; `sidebar`, which still opens over it

## Purpose

The frame for a full-screen app (a chat, a messenger, an editor with a pinned
toolbar) that has to stay put when a phone's on-screen keyboard opens. The
keyboard shrinks the visual viewport but not the layout viewport, so iOS Safari
slides a `100dvh` page up to show the focused field: the header goes off the
top and the page can be dragged around under the keyboard. Inside this frame
the header stays at the top, the composer sits on the keyboard, and only the
part meant to scroll does.

It is not for ordinary scrolling pages (an index, a settings form): those
should scroll the document as usual, and need nothing.

## API

```erb
<body>
  <%= viewport_tag class: "flex flex-col" do %>
    <header>…</header>
    <main class="min-h-0 flex-1 overflow-y-auto">…</main>
    <footer>…composer…</footer>
  <% end %>
</body>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| (none) | | | Other options go on the element; `class:` is merged |

- The content is the block. A blank block renders an empty frame.
- The part that scrolls needs `min-h-0` and `overflow-y-auto`: the frame
  itself never scrolls.

## Markup

```html
<unmagic-viewport class="UnmagicViewport flex flex-col">…</unmagic-viewport>
```

A custom element so the behaviour attaches itself when it is rendered,
including after a Turbo visit.

## Accessibility

- No role: it is a layout frame, and the landmarks inside it are the app's.
- Focus is untouched. The keyboard stays wherever the reader put it.
- Zoom still works: while the page is pinch-zoomed the frame stops following,
  so zooming in doesn't shrink the app under the reader's fingers.

## Styling

- `engine.css`, beside `.UnmagicPage`: `.UnmagicViewport` is `fixed`, top and
  sides at 0, `overflow-hidden`.
- `height: var(--unmagic-viewport-height, 100dvh)` and
  `transform: translateY(var(--unmagic-viewport-offset, 0px))`: plain
  declarations, since they read the element's numbers.
- No colours, no motion.
- The transform makes the frame the containing block for `position: fixed`
  descendants. Popovers and dialogs are in the top layer, so `sidebar`,
  `menu` and `modal` are unaffected; a host's own fixed element inside the
  frame is positioned against the frame.

## Behaviour (JavaScript)

- `<unmagic-viewport>` listens to `visualViewport` `resize` and `scroll` and
  writes `--unmagic-viewport-height` (its height) and
  `--unmagic-viewport-offset` (its `offsetTop`, Safari's pan) on `<html>`.
- On `<html>`, not the frame, because a Turbo morph rewrites the frame's own
  attributes and would drop an inline style until the next resize.
- Skips updates while `visualViewport.scale` isn't 1.
- No events. Turbo: re-attaches on connect; nothing to do on cache or morph.
- Without script, or before it runs, the frame is `100dvh`.

## I18n

None.

## Specs

`navigation_shells_spec.rb`: the element, its merged class, passthrough
attributes, and the content.

## Preview

- Not in the component browser yet: a fixed frame would cover the browser's
  own page. See open questions.
- Checked by hand in iOS 27 Safari (simulator): keyboard open and closed, the
  header staying put, sending with the keyboard up, the sidebar drawer over the
  frame, light and dark.

## Open questions

- How to show it in the component browser: an iframe example, or a page that
  is itself framed?
- Should `ai_chat` document it as the expected frame for a full-screen chat,
  or stay neutral about the page around it?
- Android Chrome resizes the layout viewport for the keyboard by default; the
  frame should be harmless there (its numbers match `innerHeight`), but it
  hasn't been checked on a device.
