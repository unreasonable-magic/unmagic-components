# `ai_chat`

> Status: draft
> Tier: 2 (small element)
> Relates to: [message](message.md), [composer](composer.md), [welcome](welcome.md), `<unmagic-autoscroll>`

## Purpose

The scrolling region a conversation's turns are rendered into, and the spacing
between them. It is assistant-ui's `Thread.Root` plus `Thread.Viewport` plus
`ScrollToBottom`: the chrome around a transcript, not the transcript itself.

A view reaches for it when it has an ordered collection of mixed entries — user
turns, assistant turns, tool calls, questions — to draw as one conversation. It
is **not** a list component: it renders no entries of its own. The host keeps its
own partial per entry type and Rails' `to_partial_path` picks between them, which
is what all three applications already do and what the gem has no business
replacing.

It is the one helper in the family with no suffix. `ai_chat` is the root the rest
are reached through, the way `card` and `menu` are roots in this gem, so
`ai_chat do |chat|` reads as the thing itself rather than as one of its parts.
Every other helper keeps the `ai_chat_` prefix.

## API

```erb
<%# The common case %>
<%= ai_chat id: "entries" do %>
  <%= render @chat.timeline %>
<% end %>

<%# Scrolling inside its own box rather than with the window, with a welcome
    screen while the conversation is empty %>
<%= ai_chat id: "entries", scroller: "#panel_body" do |chat| %>
  <% chat.welcome do %>
    <%= ai_chat_welcome heading: "What can I help with?" do |welcome| %>…<% end %>
  <% end %>
  <%= render @chat.timeline %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | string | required | The broadcast target entries are upserted into |
| `scroller:` | CSS selector | `nil` | The scrolling region; `nil` means the document |
| `follow:` | boolean | `true` | Whether to pin to the bottom as content arrives |
| `scroll_to_latest:` | boolean | `true` | Render the jump-to-latest button |

- `chat.welcome { }` records markup shown only while the transcript has no
  entries. It renders in the same element, so a first message arriving replaces
  it without a second request.
- Other options go on the root element.
- Given no block and no welcome, it renders an empty region rather than nothing:
  a broadcast can only replace an element that is already on the page.

`id:` is required because every one of these applications broadcasts into it.
Making it optional would ship a transcript that silently can't receive a turn.

## Markup

```html
<unmagic-autoscroll threshold="32">
  <div id="entries" class="UnmagicAIChatTranscript">
    <!-- the host's entries, each with its own id -->
  </div>

  <button type="button" class="UnmagicAIChatTranscript__latest" hidden
          aria-label="Jump to latest">…</button>
</unmagic-autoscroll>
```

Built on a plain `<div>` and the gem's own `<unmagic-autoscroll>`. There is no
native element for a scrolling transcript, and `<ol>` was considered and
rejected: the entries are not a list of like things, half of them are
`hidden` anchors that hold a place in the order, and an `<li>` around each would
force every host partial to render one.

## Accessibility

- The region is `role="log"` with `aria-live="polite"` and
  `aria-relevant="additions"`. A transcript is the textbook log: entries are
  added at the end and the reader wants to hear them, but not to have their
  place taken away.
- `aria-live` goes on the container the server renders, not on each entry, so a
  streamed reply is announced once when it settles rather than per flush.
  [streaming_markdown](streaming_markdown.md) carries `aria-busy` while it
  reveals, which is what suppresses the per-flush announcement.
- Scrolling never moves focus. The jump-to-latest button is a real button in the
  tab order, appears only while unpinned, and returns focus to where it was.
- The welcome content is ordinary content, announced as the log's first entry.

## Styling

CSS section: **AI chat transcript**, next to the other `UnmagicAIChat*` sections.

- `.UnmagicAIChatTranscript` — the column.
- `.UnmagicAIChatTranscript__latest` — the jump-to-latest button.

The spacing rule is the part worth writing down, and it comes from hooops:

```css
.UnmagicAIChatTranscript > :not([hidden]) ~ :not([hidden]) { margin-top: calc(var(--spacing) * 4); }
.UnmagicAIChatTranscript > :not([hidden]) ~ [data-ai-chat-cluster] { margin-top: calc(var(--spacing) * 1.5); }
```

The gap is `margin-top` on each *following* visible entry rather than a
`space-y` utility, because Tailwind v4's `space-y` puts its gap on the
*preceding* element and so cannot be tightened based on what follows. Two things
depend on being able to tighten it: a tool call the model made with no preamble
should hug the call above it rather than floating a full inter-message gap
(`data-ai-chat-cluster`), and the hidden anchors that hold a tool result's place in
the order must not earn a gap at all (`:not([hidden])`).

Colours: none on the container. The button is
`bg-white dark:bg-neutral-900`, `border-neutral-200 dark:border-neutral-800`,
`shadow-sm`, `rounded-full`.

Motion: the button fades in over 150ms and is switched off under
`prefers-reduced-motion: reduce`.

## Behaviour (JavaScript)

No element of its own. It composes [`<unmagic-autoscroll>`](../auto_scroll.md),
and the jump-to-latest button is wired by delegation from `document` — the
"behaviour on plain elements" case in the principles — so a transcript streamed
in later needs no setup.

- The button shows on `unmagic-autoscroll:unpin` and hides on `…:pin`.
- Pressing it scrolls the scroller to the bottom, which re-pins.
- Turbo: the autoscroll element owns all of it. A restored snapshot opens at the
  bottom with the button hidden.
- Needs Turbo, because the whole point of the id is the `upsert` broadcast.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.transcript.latest` | "Jump to latest" |
| `unmagic.components.ai_chat.transcript.label` | "Conversation" |

## Specs

`spec/unmagic/components/ai_chat_spec.rb`:

- The root carries the given `id`, `role="log"`, `aria-live="polite"`.
- `scroller:` reaches the `<unmagic-autoscroll>` element, not the div.
- `follow: false` renders no autoscroll element at all.
- `scroll_to_latest: false` renders no button.
- The welcome block renders inside the container, and only when there is no
  other content.
- An empty call still renders the container.
- Passthrough `class:` and attributes on the root, gem classes first.

## Preview

Page: a new `ai_chat` page, since this round adds enough components to need one.
Its section shows a transcript with a handful of static entries, one marked
`data-ai-chat-cluster` so the tightened gap is visible, and one `hidden` anchor
between two entries so it can be seen not to open a gap.

By hand: keyboard reach to the jump-to-latest button; dark theme; reduced
motion; navigate away and back and confirm it opens at the bottom.

## Open questions

- Should the gem own the page layout around the transcript — the sticky composer
  dock, the side panel? Proposed: no. All three applications place those
  differently and all three are right for their page. The gem owns the viewport
  and stops there. This is open decision 1 in the folder README.
