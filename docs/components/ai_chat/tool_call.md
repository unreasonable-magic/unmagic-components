# `ai_chat_tool_call`

> Status: draft
> Tier: 2 (small element)
> Relates to: [payload](payload.md), [transcript](transcript.md), `<unmagic-elapsed>`

## Purpose

One reach for a tool, from the ask through to the answer, as a row in the
transcript. Shut by default: the name is the interesting part at a glance, and
what exactly was asked and what came back is there for anyone who wants it.

A row rather than a box, and a run of them strung together by a hairline into a
timeline — because that is what it is. A turn is four or five calls in one
breath, and four or five bordered cards stacked up read as four or five separate
events rather than as one stretch of work. This is assistant-ui's `ToolGroup`
arrived at from the other direction, and toybox's version is better than a
wrapper: the line is drawn by every row and shown only on one that follows
another, so grouping needs no grouping element and no server-side run detection.

For a tool that ran. A tool that stopped to ask something is
[request](request.md) or [permission](permission.md) — those are not steps in a
stretch of work, they are the work stopping, and a line running through one would
say the opposite.

## API

```erb
<%= ai_chat_tool_call name: call.name, state: call.state, id: dom_id(call) do |tool| %>
  <% tool.summary call.summary %>
  <% tool.timing started_at: call.started_at, duration: call.duration %>
  <% tool.asked call.arguments %>
  <% tool.answered call.response %>
<% end %>

<%# A tool whose work is worth showing outside the fold %>
<%= ai_chat_tool_call name: "render_scene", state: :done, icon: :image do |tool| %>
  <% tool.asked call.arguments %>
  <% tool.made { render "previews", blobs: call.blobs } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `name:` | string | required | The tool's own name, unchanged |
| `state:` | `:queued`, `:running`, `:waiting`, `:done`, `:failed` | required | Validated; raises `ArgumentError` |
| `id:` | string | `nil` | For `upsert` to reconcile a redraw against |
| `icon:` | symbol | `nil` | Overrides the glyph a `:done` call shows |
| `open:` | boolean | `false` | Open on render |
| `timeline:` | boolean | `true` | Whether this row joins the run above it |

Builder parts:

- `tool.summary(text)` — what the call was actually about, beside the name.
  Three identical labels tell you nothing; "Searching messages · car seat" does.
- `tool.timing(started_at:, duration:)` — a live clock while running, the settled
  duration once done. Neither, if neither is known.
- `tool.asked(payload)` / `tool.answered(payload)` — rendered through
  [payload](payload.md).
- `tool.failures(count)` — how much of a batch didn't work, for a call that
  mostly did.
- `tool.made { }` — markup that stays outside the fold. What a call produced is
  the reason it happened, and hiding it behind a chevron is the wrong way round.
- `tool.progress(text)` — what the tool is doing while it does it, beside the
  spinner.

With no parts at all it renders the summary row alone and no disclosure, since
there would be nothing to disclose.

`icon:` exists because of the best small idea in toybox: a call that simply
worked is the common case and there is no news in it — the whole timeline is
calls that worked — so instead of a column of identical ticks the glyph says what
the call was *about*. A run then reads as shelf, shelf, file, wand rather than as
tick, tick, tick, tick. The gem cannot know a host's tool categories, so `icon:`
is the seam and a tick is the fallback.

## Markup

```html
<div id="tool_call_9" class="UnmagicAIChatToolCall" data-ai-chat-timeline="row" data-ai-chat-cluster>
  <span class="UnmagicAIChatToolCall__join" aria-hidden="true"></span>

  <details class="UnmagicAIChatToolCall__disclosure">
    <summary>
      <span class="UnmagicAIChatToolCall__glyph">…<span class="UnmagicVisuallyHidden">Done</span></span>
      <code class="UnmagicAIChatToolCall__name">search_messages</code>
      <span class="UnmagicAIChatToolCall__summary">car seat</span>
      <svg class="UnmagicAIChatToolCall__chevron" aria-hidden="true">…</svg>
      <span class="UnmagicAIChatToolCall__readings">…</span>
    </summary>

    <div class="UnmagicAIChatToolCall__body">
      <span class="UnmagicAIChatToolCall__rail" aria-hidden="true"></span>
      …asked, answered…
    </div>
  </details>
</div>
```

Built on `<details>`, so the disclosure needs no JavaScript and no state to
restore after a broadcast replaces the element — which happens on every state
change. This is the "native elements first" rule paying for itself: a scripted
disclosure would have to remember open-ness across four redraws per call.

## Accessibility

- `<details>`/`<summary>` is the disclosure pattern; the browser owns the
  expanded state, the keyboard and the announcement.
- The state glyph is `aria-hidden` and carries a visually hidden label —
  "Queued", "Running", "Waiting on you", "Failed", "Done" — because the state is
  the one thing in the row conveyed only by a glyph and a colour.
- The live clock is not a live region. See [`../elapsed.md`](../elapsed.md).
- A `:running` call's row carries `aria-busy="true"`.
- The joining line and the rail are `aria-hidden`: they are the visual grammar of
  grouping, and the reading order already groups them.
- The chevron rotates rather than changing glyph, so nothing is announced twice.

## Styling

CSS section: **AI chat tool calls**.

- `.UnmagicAIChatToolCall`, `__join`, `__disclosure`, `__glyph`, `__name`,
  `__summary`, `__chevron`, `__readings`, `__body`, `__rail`, `__made`

The timeline is the interesting CSS:

```css
.UnmagicAIChatToolCall__join {
  @apply absolute -top-3.5 left-[0.4375rem] hidden h-3 w-px -translate-x-1/2 bg-neutral-200;
}
[data-ai-chat-timeline] + [data-ai-chat-timeline] .UnmagicAIChatToolCall__join { @apply block; }
```

Every row draws the line; only a row that follows another shows it. It reaches up
into the gap above rather than taking space of its own, so what it connects is
where it would have been anyway, and it is centred on the glyph's column.

`data-ai-chat-timeline="gap"` is the companion the host has to render: a turn's
entries are not all things you can see. The message that issued three calls said
nothing itself, and each tool result holds a place in the order as an empty
element. Those are marked as gaps rather than rows, because an element that draws
nothing cannot be what separates two rows — without them a run reads as broken
wherever the transcript kept a receipt. The note for [message](message.md) says
where the host renders these.

`__rail` carries the line down the side of an open row's body, so an open call is
a stretch of the run rather than a hole in it.

Colours: neutrals throughout, amber for `:waiting`, red for `:failed`, amber for
the partial-failure count. The `:running` glyph spins, and under
`prefers-reduced-motion: reduce` it pulses opacity instead — the principles'
named exception, since a frozen spinner reads as a hang.

## Behaviour (JavaScript)

None of its own. It composes `<unmagic-elapsed>` for a running clock, and
`<details>` does the rest.

`tool.progress(text)` renders an element with its own id
(`#{id}_progress`) so the host can replace just that line as a tool reports. The
gem renders it; the host broadcasts to it.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.tool_call.queued` | "Queued" |
| `unmagic.components.ai_chat.tool_call.running` | "Running" |
| `unmagic.components.ai_chat.tool_call.waiting` | "Waiting on you" |
| `unmagic.components.ai_chat.tool_call.done` | "Done" |
| `unmagic.components.ai_chat.tool_call.failed` | "Failed" |
| `unmagic.components.ai_chat.tool_call.asked` | "Asked" |
| `unmagic.components.ai_chat.tool_call.answered` | "Answered" |
| `unmagic.components.ai_chat.tool_call.failures` | "%{count} failed" |
| `unmagic.components.ai_chat.tool_call.working` | "Working" |

## Specs

`spec/unmagic/components/ai_chat_tool_call_spec.rb`:

- Each state's glyph, classes and visually hidden label.
- `aria-busy` on a running row only.
- `data-ai-chat-timeline="row"`, and its absence under `timeline: false`.
- `icon:` overriding the done glyph, and only the done glyph.
- Each builder part in its position; `made` outside the `<details>`.
- No `<details>` at all when no part supplies content.
- `open:` reaching the `details` element.
- `ArgumentError` for an unknown state.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A run of five calls in every state, with and without summaries,
one with a partial-failure count, one with `made` content, one open, and one
standing alone between two messages so the absent join can be seen. A second
section shows the gap markers between rows.

By hand: the line joins a run and breaks between unrelated rows; an open row
keeps the line running through it; keyboard open/close; dark theme; reduced
motion (the spinner pulses).

## Open questions

- Should the gem ship a `ai_chat_tool_calls` wrapper that renders a collection and
  marks the runs itself? Proposed: no. The marking depends on entries the gem
  never sees (the empty messages and tool receipts between the rows), so a
  wrapper would only work for the simplest case and mislead in the rest.
