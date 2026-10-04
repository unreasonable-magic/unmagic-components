# `ai_chat_tool_call`

> Status: built
> Tier: 2 (small element)
> Relates to: [payload](payload.md), [transcript](transcript.md), `<unmagic-elapsed>`

## Custom element API

`ai_chat_tool_call` always renders `<unmagic-tool-call>`. The builder API is
unchanged; the temporary `element:` option and legacy renderer are removed.
The element observes `state` (`queued`, `running`, `waiting`, `done`, `failed`)
and exposes a reflecting `state` property. Missing or invalid attributes render
as queued; assigning an invalid property raises `TypeError` without changing it.
State changes update glyphs, accessible status, busy state, progress, partial
failure visibility, and selection of supplied elapsed/duration readings. They do
not recreate payloads, results, or the disclosure. `name` is also a reflecting
property/attribute for simple tool names; a supplied name part takes precedence.

Ruby supplies translated `label-queued`, `label-running`, `label-waiting`,
`label-done`, and `label-failed` attributes. Direct HTML defaults to English and
can override each label. An optional `template[data-part="success-icon"]`
contains a decorative SVG to use when done. Default glyphs are bundled locally.
Formatted failure and timing content remain caller supplied, not inferred from
elapsed wall time. The full interface requires JavaScript; before upgrade caller
content remains readable.

```erb
<%= ai_chat_tool_call name: "search_files", state: :done,
  id: "search_call" do |tool| %>
  <% tool.summary "Configuration files" %>
  <% tool.answered "config.yml" %>
<% end %>
```

Direct HTML needs no internal classes or row wrapper:

```html
<unmagic-tool-call name="search_files" state="running">
  <span data-part="summary">Finding configuration files</span>
  <span data-part="progress">Searched 12 directories</span>
  <pre data-part="payload">...</pre>
  <a data-part="result" href="/files/config">View configuration</a>
</unmagic-tool-call>
```

```js
call.state = "done"
call.setAttribute("state", "running") // same behavior
```

These are light-DOM parts, not slots. The element generates the row and applies
its internal classes. An explicit row span is also accepted for Rails helper
output. Payload and result parts may repeat. The host accepts an initial `open`
boolean and `data-ai-chat-timeline="row"` participation. Parts `elapsed`,
`duration`, and `failures` hold formatted readings; an optional `readings` wrapper
groups them. Elapsed takes precedence over duration while running. On failure,
partial-failure readings are hidden; the supplied count itself is never changed.
When a state update hides a focused progress/reading control, focus returns to
the disclosure summary (or the row when there is no disclosure).

Import `unmagic/components/tool_call` (also in the aggregate import). It imports
shared AI chat disclosure behavior, moves row/payload nodes into native
details/summary, and keeps results outside. All content is readable without script.
Payloads count by element presence, even when empty. Only direct host parts and
direct payloads in the generated body participate. Append new payloads to the
host; IDs still address parts after relocation.

Removing the last payload removes the disclosure; adding one restores it.
Reader choices use the existing ID-keyed disclosure store. Local open state also
survives losing all payloads on the same instance. A replacement without an ID
starts from `open`. Reconnection/cloning adopts generated structure. Removing a
focused summary transfers focus to the row; moving caller nodes preserves their
identity, listeners, and focus.
An upgrade enclosing an already-focused payload opens the disclosure so the
control does not become hidden. This does not overwrite the stored reader choice.

CSS pseudo-elements draw the connectors. Physical adjacency includes explicit
timeline gap markers. Requests and permissions do not participate. Hosts using
`div.UnmagicAIChatToolCall`, `__join`, or `__rail` selectors must migrate them;
those nodes no longer exist. Import `unmagic/components/tool_call` before relying
on disclosures. The aggregate import already includes it.

Verify dynamic payload insertion/removal, results outside the fold, node identity,
keyboard focus, clone/move/reconnect, ID-keyed replacement, and Turbo cache/morph.
Compare light/dark and phone layouts. Replay `bin/demo-tool-call-element.js` in
the component browser console.

### Browser verification on 3 October 2026

Manually inspected all five element states in Chrome at desktop and phone sizes,
in light and dark themes, plus mixed legacy/element neighbors and interrupted
runs. Enter and Space toggle each state; Tab visits the opened payload region
then the result link. Result-link activation leaves the disclosure unchanged.
Long summaries truncate without horizontal overflow. Fixed a discovered arrow
wrapping defect by ordering the progress line after the disclosure arrow.

The accessibility tree exposes named disclosure controls, expanded state,
translated status text, the running busy state, and named payload regions.
This is an accessibility-tree check, not a VoiceOver/NVDA speech test; actual
screen-reader output remains unverified. Testing used Chrome mobile emulation,
not physical iOS/Android devices or Safari/Firefox.

`bundle exec ruby bin/demo-tool-call-accessibility` replays settings unavailable
through Chrome DevTools MCP in a separate temporary, visible Chrome profile:
JavaScript disabled, forced colors, and reduced motion. All payloads/results
remain visible without script; connectors, focus outlines, and disclosure arrows
remain visible in forced colors; reduced motion uses a pulse instead of rotation.
It writes screenshots and results under `tmp/tool-call-manual/`.

### Reactive state verification on 4 October 2026

The replay cycles all states through both setters and attributes, including live
translation changes, custom success icons, supplied timing/failure readings,
invalid inputs, name reflection, and snapshot clones. It preserves payload node
identity, text selection, focus, and disclosure state. A focused progress control
returns focus to the summary when hidden. Properties assigned before definition
were also checked during a fresh page load. Desktop/light and mobile/dark browser
runs passed; the browser includes buttons that exercise the public state setter.

### Default renderer verification on 4 October 2026

The helper now uses the element in every repo consumer. Visible Chrome replays
passed at desktop/light and mobile/dark across the tool-call catalog (21 calls),
conversation (3 calls), and assistant workspace (1 call). State changes retained
payload identity, disclosure state and focused summaries. Native Enter opened
the workspace payload. The detailed replay also passed payload mutation, timing,
labels, focus, selection, cloning, reconnection and Turbo append/remove/morph.
Forced-colour, reduced-motion and JavaScript-disabled checks also passed with
the default renderer; all five states retained visible payloads/results without
script. No browser console errors or warnings were observed.

Replay `bin/demo-tool-call-consumers.js` from the tool-call page to visit these
consumers and exercise their state setters. No application writes are made.
The full Ruby suite passed: 526 examples. Local worktree fixtures need permission
to bind test ports and isolation from personal Git identity hooks.

## As built

Where the build differs from this note:

- There is no `data-ai-chat-cluster`; the timeline markers do that job (see [transcript](transcript.md)).
- `tool.progress` is supplied for every state; the element shows it only while running.

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

Ruby renders a readable row (`data-part="row"`) with name, summary, fallback
status and formatted readings, followed by payload and result parts. The element
wraps that row in native `details`/`summary` only when payloads exist. It owns the
state glyph and disclosure arrow; CSS owns the joining lines. There are no
server-generated decoration spans or alternate rendering paths.

Use the public parts for stream targets. A call's `id:` is copied onto the
native disclosure's `data-ai-chat-disclosure` marker so `ai_chat.js` restores
the reader's choice across replacement. `open:` supplies the initial preference.
Without JavaScript the row, payloads and results remain visible, without folding.

## Accessibility

- `<details>`/`<summary>` is the disclosure pattern; the browser owns the
  expanded state, the keyboard and the announcement.
- The state glyph is `aria-hidden` and carries a visually hidden label —
  "Queued", "Running", "Waiting on you", "Failed", "Done" — because the state is
  the one thing in the row conveyed only by a glyph and a colour.
- The live clock is not a live region. See [`../elapsed.md`](../elapsed.md).
- A `:running` call's row carries `aria-busy="true"`.
- Joining lines and rails are empty CSS pseudo-elements, absent from the
  accessibility tree; the reading order already groups the calls.
- The chevron rotates rather than changing glyph, so nothing is announced twice.

## Styling

CSS section: **AI chat tool calls**.

Internal classes style the row, disclosure, glyph, name, summary, readings,
body and result. Public `data-part` attributes identify caller-owned content.
The host's `::before` joins adjacent timeline participants; the generated body's
and result's `::before` draw the vertical rails.

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

A body pseudo-element carries the line down an open row, so an open call is
a stretch of the run rather than a hole in it.

Colours: neutrals throughout, amber for `:waiting`, red for `:failed`, amber for
the partial-failure count. The `:running` glyph spins, and under
`prefers-reduced-motion: reduce` it pulses opacity instead — the principles'
named exception, since a frozen spinner reads as a hang.

## Behaviour (JavaScript)

Import `unmagic/components/tool_call`, or the aggregate `unmagic/components`.
The element owns reactive state presentation and native disclosure structure,
and composes `<unmagic-elapsed>` for a running clock. `ai_chat.js` keeps a
person's open or shut across replacements of a call with an `id:`.

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

- Custom element output by default, with no server-generated disclosure or decoration.
- Initial state, translated labels and `aria-busy`.
- Timeline participation, `open:`, IDs, passthrough attributes and escaping.
- All caller-supplied content retained for later reactive state changes.
- Formatted timings, partial failures and custom success icon templates.
- Payload filtering, results outside the disclosure, and unknown-state validation.

The browser replay verifies state glyphs, visibility, disclosure choices and
keyboard focus after upgrade, streaming and Turbo morphs.

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
