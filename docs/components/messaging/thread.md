# `message_thread`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `ai_chat` (the AI transcript, which also follows new
> content and shows a welcome; this is the plain container), `message`

## Purpose

The container a conversation's messages sit in: the spacing between them, the
tighter spacing inside a run from one sender, and, for a conversation that
updates while it's read, the polite live region a screen reader follows.

It renders no messages of its own. The host renders each message, typically
from a partial per record, inside the block. For an agent transcript that must
follow new content and offer a way back, use `ai_chat`.

## API

```erb
<%# The common case %>
<%= message_thread do %>
  <%= render @messages %>
<% end %>

<%# A conversation broadcasts land in %>
<%= message_thread id: "messages", live: true, label: "Chat with Ana" do %>
  <%= render @messages %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | string | `nil` | The element broadcasts target |
| `live:` | boolean | `false` | `role="log"` with a polite live region for additions |
| `label:` | string | `nil` | The log's `aria-label`; not rendered without `live:`, since a plain `<div>` can't carry one |

- The block is the content. There is no builder.
- Other options go on the `<div>`.
- With no content it still renders, so a broadcast has somewhere to land.

## Markup

```html
<div id="messages" class="UnmagicMessageThread" role="log" aria-live="polite" aria-relevant="additions" aria-label="Chat with Ana">
  <div class="UnmagicMessageSeparator">…</div>
  <article class="UnmagicMessage UnmagicMessage--bubble">…</article>
  <article class="UnmagicMessage UnmagicMessage--bubble UnmagicMessage--continued">…</article>
</div>
```

A `<div>`. A log is what ARIA calls a chat, and it is only claimed when the
conversation is live; an email thread rendered once is plain content.

## Accessibility

- `live: true` renders `role="log"`, `aria-live="polite"` and
  `aria-relevant="additions"`, as `ai_chat` does, so a new message is read once
  and a replaced one isn't read again.
- Without `live:` it is a plain `<div>`, with no role and no label.
- No keyboard behaviour of its own. Messages are articles; their controls are
  in the tab order.

## Styling

CSS section: **Messages** (shared with `message`).

- `.UnmagicMessageThread`
- Spacing is margin-top on each following visible child, as `ai_chat` does, so a
  hidden entry earns no gap and a child can tighten the gap above itself:
  - a message after anything: `calc(var(--spacing) * 4)`
  - a `--continued` bubble: `calc(var(--spacing) * 0.5)`; a `--continued` row:
    `calc(var(--spacing) * 1)`
  - a separator: `calc(var(--spacing) * 6)` above
- No colours of its own.

## Small screens

Nothing of its own; the messages handle themselves.

## Behaviour (JavaScript)

_None: CSS and markup only._ A host that wants the thread to follow new content
wraps it in `<unmagic-autoscroll>` as `ai_chat` does.

## I18n

None.

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- Renders a `div.UnmagicMessageThread` with the block inside, `id:` and
  passthrough `class:` and attributes.
- `live: true` adds the log role and live-region attributes and `aria-label`;
  `live: false` adds none of them, and drops `label:`.
- Renders with no content.

## Preview

Page: `message_thread`, under the "Messaging" group. Examples: an iMessage-style
chat, a Slack-style thread, an email conversation and an AI chat, each a thread
of messages showing that one family does all four.

By hand: dark theme; a phone width; that the gap before a continued message is
tight and the gap before a separator is wide.
