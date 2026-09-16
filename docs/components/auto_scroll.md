# `<unmagic-autoscroll>`

> Status: draft
> Tier: 2 (small element)
> Relates to: [ai_chat/transcript](ai_chat/transcript.md), which wraps it

## Purpose

Keeps the page pinned to the bottom while content streams into an element — but
only while the reader is already there. Scroll up to re-read something and new
content doesn't yank you back down; scroll to the bottom again and following
resumes.

For any growing region: an agent transcript, a log tail, a live import report.
Not for a region that grows at the *top* (a paginated history loading upwards);
that is a scroll-anchoring problem and this element would fight it.

This exists in hooops and toybox as the same Stimulus controller, already
drifted: one uses private fields and the other doesn't, and the comments have
been reworded past each other. It is the plainest extraction in the round.

## API

```erb
<%# Wrapping whatever grows %>
<unmagic-autoscroll>
  <div id="entries"><%= render @entries %></div>
</unmagic-autoscroll>

<%# With a scroll-to-latest button, and a looser threshold %>
<unmagic-autoscroll threshold="64">…</unmagic-autoscroll>
```

There is no Ruby helper and no component class. It is markup a view writes
directly, like `<uuid-input>`. `ai_chat`, the family's root helper, renders it for a transcript.

| Attribute | Values | Default | Notes |
|---|---|---|---|
| `threshold` | integer, px | `32` | How close to the bottom still counts as "at the bottom" |
| `scroller` | CSS selector | — | The scrolling region. Absent means the document |

`scroller` is what kp2 needed and the other two didn't: its assistant lives in a
slide-out panel whose transcript scrolls inside its own box, while on a full
page the window is the scroller. Both applications' versions hard-coded
`document.scrollingElement`; the attribute is the generalisation.

## Markup

None. The element is a passthrough — `display: contents` — so it never
participates in its parent's layout.

```html
<unmagic-autoscroll threshold="32">
  <!-- the growing content, untouched -->
</unmagic-autoscroll>
```

## Accessibility

- Scrolling is not announced and does not move focus. A reader using a screen
  reader hears new content because it is in the page, not because the viewport
  moved.
- Following stops the instant the reader scrolls, which is the accessible
  behaviour: the element never takes the viewport away from someone reading.
- Under `prefers-reduced-motion: reduce` the scroll is instant rather than
  smooth. It is already instant in both source implementations, so this is
  a constraint to keep rather than to add.
- The scroll-to-latest button that `ai_chat` pairs with this is where
  the announcement belongs, not here.

## Styling

CSS section: **Auto scroll**, one rule.

```css
unmagic-autoscroll { display: contents; }
```

No colours, no state, no knobs.

## Behaviour (JavaScript)

`<unmagic-autoscroll>` — reads `threshold` and `scroller`.

- A `MutationObserver` on the element (`childList`, `subtree`, `characterData`)
  scrolls the scroller to the bottom on every change, but only while pinned.
- A passive `scroll` listener on the scroller decides pinned: within `threshold`
  pixels of the bottom.
- Fires `unmagic-autoscroll:pin` and `unmagic-autoscroll:unpin`, bubbling, so a
  scroll-to-latest button can show and hide itself without measuring anything.
- Turbo:
  - `connectedCallback` scrolls to the bottom once, so a restored snapshot opens
    at the latest rather than wherever it was cached.
  - The observer and the listener are both torn down in `disconnectedCallback`.
  - A morph refresh replaces children without touching this element, and the
    observer sees that as content changing, which is correct.
  - No `turbo:before-cache` work: scroll position isn't state worth resetting.
- Needs no Turbo itself.

## I18n

None. The element prints nothing.

## Specs

There are no JavaScript specs in this gem, so verification is by hand in the
preview. What to check is listed under Preview.

## Preview

Page: `elements`. A section with a button that appends a paragraph every 300ms
into an `<unmagic-autoscroll>`, plus a second one inside a fixed-height box
using `scroller`.

By hand:

- It follows while you sit at the bottom.
- Scroll up mid-stream: it stops following, and stays stopped.
- Scroll back to the bottom: following resumes.
- The `scroller` variant follows its own box and leaves the window alone.
- Navigate away and back: it opens at the bottom, not at the cached position.
- Reduced motion: no smooth scrolling anywhere.

## Open questions

- Should `unpin` be sticky until the reader returns to the bottom, or should a
  large programmatic jump (an anchor link into the history) re-pin? Both source
  implementations are silent on this because neither has anchors into the
  transcript. Proposed: only the reader's own scrolling re-pins.
