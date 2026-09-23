# `message_typing`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `message` (it looks like another's bubble),
> `spinner`, `ai_chat_message`'s thinking spinner

## Purpose

Someone is writing. Three dots in a bubble, with the writer's name, at the foot
of a thread while a reply is on its way.

For a person typing, or an assistant that hasn't started its answer. An answer
that is streaming in is `ai_chat_message` with `streaming: true`.

## API

```erb
<%= message_typing "Ana Silva" %>
<%= message_typing "Ana Silva", avatar: true %>
<%= message_typing %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| who (positional) | string | `nil` | The writer's name, shown above the dots and read as "Ana Silva is typing" |
| `avatar:` | `true`, a name, or a Hash of `avatar` options | `nil` | Beside the bubble, as `message` draws it |

Other options go on the root.

## Markup

```html
<div class="UnmagicMessageTyping">
  <div class="UnmagicMessageTyping__avatar">…</div>
  <div class="UnmagicMessageTyping__main">
    <span class="UnmagicMessageTyping__author" aria-hidden="true">Ana Silva</span>
    <span class="UnmagicMessageTyping__bubble" aria-hidden="true"><i></i><i></i><i></i></span>
    <span class="UnmagicVisuallyHidden">Ana Silva is typing</span>
  </div>
</div>
```

## Accessibility

- No live region of its own. Inside a `message_thread live: true` the log
  announces its arrival as "Ana Silva is typing" (or "Typing"); a nested
  `role="status"` would announce it twice. Outside a live thread, pass
  `role: "status"`.
- The dots and the visible name are `aria-hidden`; the sentence is the only
  text a reader hears.

## Styling

CSS section: **Message typing**.

- `.UnmagicMessageTyping`, `__avatar`, `__main`, `__author`, `__bubble`; its own
  avatar class, so the row rules on `UnmagicMessage__avatar` never reach it
- Laid out like another's bubble: `flex items-end gap-2`; the bubble is
  `inline-flex gap-1 rounded-2xl rounded-bl-sm bg-neutral-100 px-4 py-3
  dark:bg-neutral-800`; the dots are `size-1.5 rounded-full bg-neutral-400
  dark:bg-neutral-500`.
- The dots rise in turn: a 1.2s `translateY` keyframe, each dot delayed by
  0.2s. Under `prefers-reduced-motion: reduce` the movement is replaced by an
  opacity pulse, so the indicator never looks frozen.

## Small screens

Nothing of its own.

## Behaviour (JavaScript)

_None._ The host renders it while someone types (a broadcast) and removes it
when the message arrives.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.message.typing.named` | "%{name} is typing" |
| `unmagic.components.message.typing.anonymous` | "Typing" |

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- No role unless passed; the visually hidden sentence with and without a
  name; the visible name is `aria-hidden`; three dots, `aria-hidden`.
- `avatar:` draws the avatar; passthrough `class:`.

## Preview

Page: `message_typing`. Named, anonymous, with an avatar, and at the foot of a
thread.

By hand: reduced motion (the dots pulse instead of rising); dark theme.
