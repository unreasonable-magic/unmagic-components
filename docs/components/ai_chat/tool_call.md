# `ai_chat_tool_call`

> Status: built
> Tier: 2 (small element)
> Relates to: [payload](payload.md), [reasoning](reasoning.md), [transcript](transcript.md), `<unmagic-elapsed>`

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

The Ruby API is unchanged by the redesign.

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
| `id:` | string | `nil` | For `upsert` to reconcile a redraw against, and the stream targets below |
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

`icon:` exists because of the best small idea in toybox: a call that simply
worked is the common case and there is no news in it — the whole timeline is
calls that worked — so instead of a column of identical ticks the glyph says what
the call was *about*. A run then reads as shelf, shelf, file, wand rather than as
tick, tick, tick, tick. The gem cannot know a host's tool categories, so `icon:`
is the seam and a tick is the fallback.

## Markup

The markup is HTML a person could write, and it means what it says. The fold
is a `<details>`, its row is the `<summary>`, the payloads are the `<figure>`s
the details holds, and the result is whatever follows the details. Nothing is
named by an attribute or a class, nothing is moved or wrapped by script, and
the only id is the host's.

```html
<unmagic-tool-call name="search_files" state="done" id="call_9" data-ai-chat-timeline="row">
  <details>
    <summary>
      <code>search_files</code>
      <span>red lantern</span>
      <time datetime="PT0.64S">640ms</time>
    </summary>
    <figure>
      <figcaption>Asked</figcaption>
      <div role="region" tabindex="0" aria-label="Asked"><pre><code>…</code></pre></div>
    </figure>
    <figure>
      <figcaption>Answered</figcaption>
      <div role="region" tabindex="0" aria-label="Answered"><pre><code>…</code></pre></div>
    </figure>
  </details>
  <div><a href="/files/lantern-red.glb">Open the file</a></div>
</unmagic-tool-call>
```

Written by hand, the smallest useful call is:

```html
<unmagic-tool-call name="search_files" state="running">
  <details>
    <summary>Finding configuration files <output>Searched 12 directories</output></summary>
    <pre>…</pre>
  </details>
  <a href="/files/config">View configuration</a>
</unmagic-tool-call>
```

What each child is, by what it is:

| Child | Of | Is |
|---|---|---|
| `details` | the host | the fold |
| `summary` | the details | the row |
| `code` | the summary | the tool's name; inserted from `name` if absent |
| `span` | the summary | the summary text (`tool.summary`), truncated when long |
| `output` | the summary | progress (`tool.progress`), shown only while running |
| `unmagic-elapsed` | the summary | the live clock, shown only while running |
| `time` | the summary | the settled duration, as `datetime="PT…S"`, hidden while a clock is beside it |
| `data` | the summary | the partial-failure count, as `value="2"`, hidden once failed outright |
| `figure` | the details | a payload: see [payload](payload.md) |
| anything after the details | the host | the result (`tool.made`) |

Ruby always renders the details and summary, even for a call with nothing to
show yet, because `<summary>` has no meaning outside `<details>` and because a
queued call's payloads will arrive into it. Each reading leads with an icon and
a visually hidden label ("Took", "Running for", "Partly failed").

The one node the element owns is the glyph, a `<span data-tool-call-glyph>`
first in the summary, carrying the state it was drawn for. Ruby seeds it with
the current state's icon, aria-hidden, and the visually hidden status word, so
the state is read before any script runs and the first render changes nothing.
For a call given an `icon:` that may become done later, a `<template>` inside
the glyph keeps that icon for the element to use then. Nobody writes the glyph
by hand: a hand-written call gets one when the element upgrades.

**An empty fold.** A details that holds only its summary is a chevron that opens
onto nothing, and a screen reader calls it a collapsed button. CSS hides the
chevron and takes the pointer off the summary while the details is empty
(`details:not(:has(> :not(summary)))`), and the element takes the summary out of
the tab order until a payload arrives. The row still reads as a row. This is the
cost of native markup, paid once, and it is cheaper than generating the fold.

**Reader's choice.** A call with an `id:` remembers whether the reader opened or
shut its fold, across a Turbo Stream replace and a morph, in the memory
`ai_chat.js` keeps for the family's disclosures, keyed by the host's id. Nothing
marks the details. `open:` decides only until they choose.

### Streaming

A host that broadcasts as a call goes along never names the children. The
Turbo Stream tag builder gains `ai_chat_tool_call`, with the view helper's
vocabulary, one stream per part:

```ruby
render turbo_stream: turbo_stream.ai_chat_tool_call(dom_id(call)) do |tool|
  tool.progress "Frame 13 of 40"
end

render turbo_stream: turbo_stream.ai_chat_tool_call(dom_id(call)) do |tool|
  tool.answered call.response, duration: call.duration
  tool.made { render "previews", blobs: call.blobs }
  tool.state :done
end
```

| Part | Emits |
|---|---|
| `asked` / `answered` | `append_all "#call_9 > details"` with a payload figure |
| `progress` | `update_all "#call_9 > details > summary > output"`, keeping the node |
| `made` | `append "call_9"`, after the details |
| `state` | the `tool_call_state` action, which sets the host's attribute |

`state` is the one part that needs an action of its own, since no standard
action changes an attribute without replacing the element. From a model, where
there is no tag builder, `broadcast_action_to` takes the same `targets:`
selectors, and `tool_call_state` is a tag with a `state` attribute. When the
call settles, upsert the whole entry as the transcript does for everything else.

## Accessibility

- `<details>`/`<summary>` is the disclosure pattern; the browser owns the
  expanded state, the keyboard and the announcement, with or without script.
- The state glyph is `aria-hidden` and carries a visually hidden label —
  "Queued", "Running", "Waiting on you", "Failed", "Done" — because the state is
  the one thing in the row conveyed only by a glyph and a colour. Ruby renders
  the initial one; the element keeps it true.
- Progress is an `<output>`, which is a polite live region by default: the one
  line in the row that changes while a person watches is the one worth hearing.
  A host that reports too often for that sets `aria-live="off"` on it.
- The live clock is not a live region. See [`../elapsed.md`](../elapsed.md).
- A `:running` call's host carries `aria-busy="true"`.
- Joining lines and rails are empty CSS pseudo-elements, absent from the
  accessibility tree; the reading order already groups the calls.
- The chevron rotates rather than changing glyph, so nothing is announced twice.
- An empty fold's summary is out of the tab order; see Markup.
- The scrollable payload region is named for its caption; see
  [payload](payload.md).

## Styling

CSS section: **AI chat tool calls**.

Nothing is styled by class, and nothing is styled by a part name. The element
is its tag, its state is its attribute, and its parts are the elements they
are: `unmagic-tool-call[state="failed"] > details > summary > code` colours a
failed call's name. The glyph is `[data-tool-call-glyph]`. Rules reach the
summary's children through child combinators, so a call nested in another's
payload keeps its own colours.

The summary is the flex row: glyph, name, summary text, readings, chevron
(`summary::after`), with progress on a line of its own below (`basis-full`,
ordered last so the chevron cannot wrap under it). The summary text truncates;
bare text written without a span still shows, just without truncation.

Which readings show is CSS, from the state attribute: `output` and
`unmagic-elapsed` only while running, `time` hidden while running when an
elapsed clock is beside it (`summary:has(> unmagic-elapsed)`), `data` hidden
once the call has failed outright. No script toggles `hidden`.

Payloads are `details > figure`, and everything after the details is a result
block: `unmagic-tool-call > details ~ *` gets the indent and its own rail. The
host's `::before` joins adjacent timeline participants; the open details'
`::after` and each result's `::before` draw the vertical rails. Every row draws
the line; only a row that follows another shows it. It reaches up into the gap
above rather than taking space of its own, so what it connects is where it
would have been anyway, and it is centred on the glyph's column.

`data-ai-chat-timeline="gap"` is the companion the host has to render: a turn's
entries are not all things you can see. The message that issued three calls said
nothing itself, and each tool result holds a place in the order as an empty
element. Those are marked as gaps rather than rows, because an element that draws
nothing cannot be what separates two rows — without them a run reads as broken
wherever the transcript kept a receipt. The note for [message](message.md) says
where the host renders these.

Colours: neutrals throughout, amber for `:waiting`, red for `:failed`, amber for
the partial-failure count. The `:running` glyph spins, and under
`prefers-reduced-motion: reduce` it pulses opacity instead — the principles'
named exception, since a frozen spinner reads as a hang. Under forced colours
the rails take `CanvasText`.

## Behaviour (JavaScript)

Import `unmagic/components/tool_call`, or the aggregate `unmagic/components`.
With the fold native, the element is small. It:

- observes `state` and the `label-*` attributes, and reflects `state` and
  `name` as properties. An unknown state reads as queued; assigning one throws
  without changing the attribute;
- keeps the glyph: on a state or label change it swaps the icon (the bundled
  set, or the done icon from the glyph's template) and the status word, and
  sets or clears `aria-busy` on the host;
- inserts `<code>` from `name` into a hand-written summary that has none, and
  updates it when the attribute changes. A name the server wrote is the
  server's;
- keeps an empty fold's summary out of the tab order, and puts it back when a
  payload arrives, watching the fold's children for that;
- defines the `tool_call_state` Turbo Stream action, which sets `state` on
  each target.

It does not create, move, wrap or remove anything else. Payloads, results and
progress are where the server or the stream put them, with their listeners and
focus intact, and a Turbo morph of the whole call morphs a stable tree. On
`turbo:before-cache` there is nothing to reset. It composes `<unmagic-elapsed>`
for the clock, which keeps the glyph and label the row puts before its reading,
and leans on `ai_chat.js` for the reader's choice, which that script keys by the
host's id for a tool call's fold as it keys the rest of the family by their
marker.

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
| `unmagic.components.ai_chat.tool_call.partly_failed` | "Partly failed" |
| `unmagic.components.ai_chat.tool_call.running_for` | "Running for" |
| `unmagic.components.ai_chat.tool_call.took` | "Took" |

## Specs

`spec/unmagic/components/ai_chat_tool_call_spec.rb`:

- The native shape: details, summary with code, span, readings as
  `time`/`data`/`unmagic-elapsed`, progress as `output`, figures inside the
  details, `made` after it, and no class, part or id on any child.
- The glyph seeded for the state, with its word and the done icon's template.
- `open:`, `timeline:`, `aria-busy`, translated labels, passthrough `class:`
  and attributes, escaping, and `ArgumentError` for an unknown state.
- A call with no parts still renders an empty details and summary.
- The stream builder: each part's action and target, and the state action.

`spec/e2e/ai_chat_tool_call_spec.rb`, in headless Chrome:

- The markup is left as the server wrote it, plus the glyph.
- An empty fold shows no chevron and is skipped by Tab; a streamed payload
  gives it both back.
- A payload appended to the details, progress updated, a result appended and
  a state set through the stream actions all land where they should, and the
  state change leaves them alone.
- State colours reach the glyph and the name, helper's and hand-written alike.
- Which readings show in each state, from CSS, including the clock over the
  duration.
- The reader's choice survives a replace and a morph of a call with an id, and
  not of one without.
- Every state by property and by attribute, relabelling, name reflection, and
  a clone keeping one glyph.
- Each consumer on a desktop in light and a phone in dark, with the keyboard.
- Reduced motion pulses the spinner; forced colours keep the rails visible.
- Without JavaScript the fold toggles natively, the state reads, and every
  payload and result is on the page.

## Preview

Page: `ai_chat_tool_call`. "A run of calls", "Every state" (each with every
reading, so the state alone decides what shows), "What went in and what came
back" (the payloads, open), "What a call made", and "Written by hand", which
shows the hand-written form from Markup beside the helper's output, with
buttons that change its state and add a payload.

By hand: open and shut a fold with JavaScript off; Tab past a queued call;
the line joins a run and breaks between unrelated rows; an open row keeps the
line running through it; dark theme; reduced motion.

## Open questions

- Should the family's other disclosures (reasoning, plans, workspace sections)
  be keyed by an id of their own too, so the `data-ai-chat-disclosure` marker
  goes everywhere? Proposed: yes, as a follow-up, since it touches four
  components and this note only needed the tool call.
- Should `code_view` get the same treatment, selected by a tag and its native
  children rather than classes? Its class is the one that still appears inside
  a payload's region. Proposed: decide for the whole gem in the principles
  rather than one component at a time.
- Should the gem ship an `ai_chat_tool_calls` wrapper that renders a collection
  and marks the runs itself? Proposed: no. The marking depends on entries the
  gem never sees (the empty messages and tool receipts between the rows), so a
  wrapper would only work for the simplest case and mislead in the rest.
