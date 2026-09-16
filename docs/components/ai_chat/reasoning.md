# `ai_chat_reasoning`

> Status: built
> Tier: 1 (no JS)
> Relates to: [message](message.md), [tool_call](tool_call.md), `accordion`

## As built

Where the build differs from this note:

- A streaming block reveals through `<unmagic-streaming-markdown>` only when the reasoning has an `id:` to stream into; `ai_chat_message` gives it `"#{id}_reasoning"`.

## Purpose

The model's thinking, collapsed above the reply it led to. Shut by default,
because it is working-out rather than an answer, and available because when a
reply is wrong the working-out is the first place anyone looks.

This is assistant-ui's `ReasoningGroup`, and hooops and kp2 both built the
single-block version of it as a "Thought process" disclosure.

For reasoning content a provider hands back. Not for a tool call's payloads —
that is [tool_call](tool_call.md) — and not for a general disclosure, which is
the planned [`accordion`](../accordion.md).

## API

```erb
<%= ai_chat_reasoning do %><%= Markdown.render(message.thinking_text) %><% end %>

<%# Several blocks from one turn, grouped %>
<%= ai_chat_reasoning streaming: true, duration: 12.4 do |reasoning| %>
  <% message.thinking_blocks.each { |b| reasoning.block { Markdown.render(b) } } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `title:` | string | "Thought process" | |
| `streaming:` | boolean | `false` | Renders "Thinking…" and a spinner instead of the title |
| `duration:` | seconds | `nil` | "Thought for 12s", once settled |
| `open:` | boolean | `false` | |

- `reasoning.block { }` records one block; repeatable. Content given directly is
  one block.
- Blank content renders nothing at all. A turn with no reasoning should leave no
  chrome, unlike [plan](plan.md) — nothing broadcasts into this element.

`duration:` is the small thing worth having that neither application built:
"Thought for 12s" is the one fact about reasoning a reader actually wants at a
glance, and the number is already on the record.

## Markup

```html
<details class="UnmagicAIChatReasoning">
  <summary class="UnmagicAIChatReasoning__head">
    <span class="UnmagicAIChatReasoning__title">Thought for 12s</span>
    <svg class="UnmagicAIChatReasoning__chevron" aria-hidden="true">…</svg>
  </summary>
  <div class="UnmagicAIChatReasoning__block UnmagicProse">…</div>
</details>
```

## Accessibility

- `<details>`/`<summary>`, so the browser owns the disclosure.
- While `streaming:`, the summary carries `aria-busy="true"` and the spinner is
  `aria-hidden` with a visually hidden "Thinking".
- The blocks are ordinary prose. Not a live region: reasoning streams fast and
  announcing it would drown the reply it precedes.

## Styling

CSS section: **AI chat reasoning**.

- `.UnmagicAIChatReasoning`, `__head`, `__title`, `__chevron`, `__block`

Quiet: `max-w-[80%] rounded-xl border border-neutral-200 bg-neutral-50 px-3 py-2
text-xs text-neutral-500` with the dark pairs. Narrower and smaller than the
reply, so the eye passes over it on the way down.

The chevron rotates on `[open]`. The spinner pulses under reduced motion.

## Behaviour (JavaScript)

None of its own. When `streaming:`, the block is wrapped in
`<unmagic-streaming-markdown>` so reasoning reveals at the same pace the reply
does.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.reasoning.title` | "Thought process" |
| `unmagic.components.ai_chat.reasoning.thinking` | "Thinking…" |
| `unmagic.components.ai_chat.reasoning.duration` | "Thought for %{duration}" |

## Specs

`spec/unmagic/components/ai_chat_reasoning_spec.rb`:

- Blank content renders nothing.
- `streaming:` renders the busy summary and wraps blocks in the streaming
  element; settled does neither.
- `duration:` renders the duration title and takes precedence over `title:`.
- Repeated `block` renders several blocks in order.
- `open:` reaches the `details`.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A settled block with a duration; a streaming one; a three-block
one; and one above a reply, which is where it actually lives.

By hand: keyboard open/close; dark theme; reduced motion.

## Open questions

- Should reasoning blocks from consecutive turns group into one disclosure, as
  assistant-ui's `ReasoningGroup` does? Proposed: no. Grouping across turns needs
  run detection the gem cannot do (see the same argument in
  [tool_call](tool_call.md)), and within a turn `reasoning.block` already groups.
