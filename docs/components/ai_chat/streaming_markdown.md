# `<unmagic-streaming-markdown>`

> Status: draft
> Tier: 3 (large)
> Relates to: [message](message.md), the `stream_markdown` action, `upsert`

## Purpose

Reveals server-rendered HTML at a steady pace as it arrives, so a model's reply
reads as one smooth stream rather than as the bursts it actually lands in.

The server renders the reply to HTML and broadcasts the whole render on every
flush. Snapshots arrive in bursts — one per server flush, and the model itself
produces tokens unevenly — which paints chunkily. This element decouples reveal
cadence from arrival: it holds the newest full render as a target and eases a
character cursor toward it every animation frame.

For streamed prose. Not for a progress bar, a log tail or anything whose arrival
*is* the information — those should paint immediately.

This is hooops's `streaming_markdown.js`, which is the most considered piece of
UI in any of the three applications. It lifts nearly verbatim: it is already a
custom element, already dependency-free apart from Turbo, and already solves
problems the other two have not hit yet.

## API

```erb
<%# Through ai_chat_message, which is how it is normally reached %>
<%= ai_chat_message role: :assistant, id: dom_id(m), streaming: true do %>…<% end %>

<%# Directly %>
<%= streaming_markdown_tag id: "reply_1_content", class: "UnmagicProse" do %>
  <%= Markdown.render(reply.content) %>
<% end %>
```

Broadcast a flush with the stream action the gem registers beside `upsert`:

```ruby
broadcast_action_to chat, action: :stream_markdown, target: "#{element_id}_content",
  html: Markdown.render(content)
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | string | required | The flush target, and the handoff key |
| `final:` | boolean | `false` | Settled: show as-is, refuse any later flush |

- Content is a block: already-rendered, already-sanitised HTML.
- With no content it renders an empty element, which is what a turn looks like
  before its first token.
- The gem does not parse Markdown. See the folder README.

## Markup

```html
<unmagic-streaming-markdown id="message_2_content" class="UnmagicProse" aria-busy="true">
  <p>Already revealed…</p>
</unmagic-streaming-markdown>
```

The server renders whatever has arrived so far, so a reload mid-reply shows the
partial reply rather than nothing, and the element reveals onward from there.

## Accessibility

- `aria-busy="true"` while revealing, removed when the cursor reaches the live
  edge. This is what stops the transcript's `aria-live` region announcing every
  flush: an assistive technology skips a busy subtree and announces once it
  settles.
- Under `prefers-reduced-motion: reduce` there is no reveal at all — each
  snapshot paints in full, immediately. A character-by-character reveal is
  exactly the kind of motion that rule is for.
- The revealed prefix is real DOM, not a CSS trick, so selection, find-in-page
  and copy all work on what is visible.

## Styling

None of its own beyond `display: block`. The prose styling is `UnmagicProse`, a
separate section of `engine.css` this component only names.

`UnmagicProse` is worth extracting in its own right: hooops and toybox both hand-wrote
a prose stylesheet for exactly this content, and the gem's `detail_list` and
`callout` already have opinions that should agree with it.

- Type: `text-sm`, `leading-relaxed`, `overflow-wrap: break-word` on every block,
  because a model emits URLs and digests that no column can hold.
- First and last child margins collapsed to zero, so prose sits flush in a
  bubble or a card.
- Headings, lists, tables, blockquote, `hr`, inline and block code, and task
  lists, all in palette neutrals with `dark:` pairs.
- Block code carries the chrome only; the tokens are the host's highlighter's,
  through the same seam [payload](payload.md) uses.

No motion in CSS — the reveal is JavaScript rewriting the DOM, so there is
nothing for `prefers-reduced-motion` to switch off here. The element checks it.

## Behaviour (JavaScript)

`<unmagic-streaming-markdown>` — reads `id` and `final`.

The reveal strategy, which is the whole component:

- Reveal at **constant velocity** — the model's own average production rate —
  and let the buffer (how far the cursor trails the live edge) absorb the bursts,
  rather than the speed. A proportional "close a fraction of the gap" scheme
  makes velocity rise and fall with the backlog, so the reveal visibly speeds up
  and slows down on every burst.
- The arrival rate is an EMA over ~0.6s. A gentle pull toward a small target
  buffer (~0.3s of text) keeps the trailing distance from drifting, soft enough
  that the speed ripple is a few percent rather than ±100%.
- A latency cap drains any backlog within ~1.5s, for a reconnect or a paste.
- A trickle floor (~24 chars/sec) finishes the tail.

The reconcile:

- The visible prefix is rebuilt block by block. Settled leading blocks —
  identical by tag and text — are left untouched; everything from the first
  changed block is re-rendered from the snapshot. Rebuilding a whole block rather
  than splicing its text keeps container blocks (lists, tables) structurally
  intact.

The handoff, which is the part that isn't obvious:

- When the settled turn upserts over the streaming one mid-reveal, the
  replacement resumes from where the old one left off — reveal progress is
  stashed in a module-level `Map` keyed by element id — and paces to the end, so
  the buffered tail flows in instead of the whole reply snapping into place.
- It only continues when the new render actually *extends* what was on screen. A
  divergent settle (a "Response stopped" note, an error) does not start with the
  revealed text, so it just shows at once.
- `final` deletes the handoff and freezes: a stopped or failed turn refuses any
  flush still in flight, which is what makes the Stop button's optimistic swap
  stick before the server has settled the turn.

Turbo:

- The stashed progress is in a module-level `Map` keyed by id, not on the
  element, which is the permanent-element rule from the principles applied to a
  replaced element instead of a moved one.
- `disconnectedCallback` cancels the frame and stashes; `connectedCallback`
  claims and resumes, or shows in full.
- Needs Turbo, for `Turbo.StreamActions.stream_markdown`.

Fires `unmagic-streaming-markdown:settle` when the cursor reaches the live edge.

## I18n

None. The element prints nothing of its own.

## Specs

`spec/unmagic/components/ai_chat_streaming_spec.rb` covers only the Ruby:

- The helper's element, `id`, and the `final` attribute.
- Content passed through unescaped, and blank content rendering an empty element.
- `aria-busy` present when not final.
- The `stream_markdown` stream action's tag, target and template.

The reveal itself has no specs, per the gem's rule. The preview is the test, and
the checklist below is what it has to pass.

## Preview

Page: `ai_chat`. A section with a fake stream: a Reveal button that flushes a long
document in uneven bursts, with controls for burst size and gap, plus a Stop
button that swaps in a `final` element mid-reveal.

By hand:

- The reveal is smooth through an uneven burst pattern — no visible surging.
- A huge single jump catches up within about a second rather than crawling.
- The tail finishes rather than stalling a few characters short.
- Lists and tables never flicker or re-nest as they grow.
- Stop mid-reveal: the note appears at once and no later flush overwrites it.
- Reduced motion: every flush paints in full, immediately.
- Navigate away and back mid-reveal: no runaway animation frames.

## Open questions

- The constants (rate smoothing, buffer, softness, lag cap, trickle floor) are
  tuned against one provider's cadence. Should they be knobs? Proposed: no —
  a knob per constant is five knobs nobody can set meaningfully. If a second
  application needs different numbers, that is evidence for a named preset, not
  for five dials.
