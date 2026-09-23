# `message_reactions`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `message` (rendered into `m.reactions { }`), `badge`

## Purpose

The emoji people have put on a message, each with its count and whether the
viewer is among them, and a button to add one. Rendered into
`message.reactions { }`, under the body.

For reactions on a message. A vote or a rating is a form control.

## API

```erb
<%= message_reactions do |r| %>
  <% r.reaction "👍", count: 3, reacted: true, names: [ "Ana", "Ben", "You" ], url: react_path(message, "+1") %>
  <% r.reaction "🎉", count: 1, url: react_path(message, "tada") %>
  <% r.add popovertarget: "picker_#{message.id}" %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | "Reactions" | The list's `aria-label` |

Builder parts:

- `r.reaction(emoji, count: 1, reacted: false, names: [], url: nil, method: :post, **options)`
  — a pill. With `url:` it is a `button_to` (a toggle the host handles);
  without, a static span. `reacted:` marks the viewer's own; `names:` lists who,
  in the title.
- `r.add(content = nil, **options, &block)` — the "add a reaction" control. With
  no content, an icon button labelled "Add reaction" carrying `**options`
  (`popovertarget:`, `data:`), so the host wires it to its picker. With content
  or a block, that markup instead.

With no parts it renders nothing. Other options go on the `<ul>`.

## Markup

```html
<ul class="UnmagicMessageReactions" aria-label="Reactions">
  <li><form class="UnmagicMessageReactions__form" action="…" method="post">
    <button class="UnmagicMessageReactions__reaction" type="submit" aria-pressed="true" title="Ana, Ben and You">
      <span class="UnmagicMessageReactions__emoji">👍</span><span class="UnmagicMessageReactions__count">3</span>
    </button>
  </form></li>
  <li><span class="UnmagicMessageReactions__reaction" data-reacted="">…<span class="UnmagicVisuallyHidden">You reacted</span></span></li>
  <li><button class="UnmagicButton UnmagicButton--icon UnmagicMessageReactions__add" type="button" aria-label="Add reaction" title="Add reaction" popovertarget="picker_1">…</button></li>
</ul>
```

A list, because it is one; forms, because toggling a reaction is a request the
host already handles, and a form needs no script.

## Accessibility

- A labelled list; each pill is a toggle button with `aria-pressed`, so a reader
  hears "thumbs up 3, pressed". The emoji is text and reads as its name.
- A static reacted pill (no `url:`) can't be pressed, so it says "You reacted"
  in visually hidden text instead.
- `names:` go in the `title`, as `avatar_group`'s "+N" does; a hover detail,
  not the only way to know the count.
- The add button is icon-only, with `aria-label` and `title`.
- Nothing is colour-only: a reacted pill is outlined and pressed, not just
  tinted.

## Styling

CSS section: **Message reactions**.

- `.UnmagicMessageReactions`, `__form`, `__reaction`, `__emoji`, `__count`,
  `__add`
- The list: `m-0 flex list-none flex-wrap items-center gap-1 p-0`.
- A pill: `inline-flex min-h-7 items-center gap-1 rounded-full border
  border-neutral-200 bg-white px-2 text-xs tabular-nums text-neutral-700`,
  `dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-300`; a button
  pill has `cursor-pointer`, `font: inherit`, hover `bg-neutral-50`, the shared
  focus ring. `[aria-pressed="true"]` and `[data-reacted]`: `border-blue-300
  bg-blue-50 text-blue-700 dark:border-blue-500/40 dark:bg-blue-400/10
  dark:text-blue-300`.
- The add button is an icon button with a `size-3.5` glyph and `text-neutral-500`.
- Under a coarse pointer the pills stay 28px tall (a 44px pill is a badge) but
  a `::before` extends the hit area to 44px, with a comment saying why.
- Motion: none.

## Small screens

Pills wrap. Hit areas are 44px under a coarse pointer (above).

## Behaviour (JavaScript)

_None: CSS and markup only._ A picker is the host's; the examples use a native
`popover` of emoji buttons.

The pressed state is the server's: a toggle posts, and the host's response
re-renders the reactions (a Turbo Stream replace of the message or of the list)
with the new `aria-pressed`. A response that navigates works too; nothing flips
in place without a render.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.message.reactions.label` | "Reactions" |
| `unmagic.components.message.reactions.add` | "Add reaction" |
| `unmagic.components.message.reactions.reacted` | "You reacted" |

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- A labelled `<ul>`; a reaction with `url:` is a `button_to` with the method,
  `aria-pressed` from `reacted:`, `title` from `names:`, emoji and count; one
  without is a span with `data-reacted` when reacted.
- `add` renders the labelled icon button with passthrough options, or the
  given markup.
- No parts renders nothing; passthrough `class:`.

## Preview

Page: `message_reactions`. Pills with counts, one reacted, the add button
opening a native popover of emoji, and a message carrying them.

By hand: Tab through the pills and press one (the demo posts nowhere); the
popover from the keyboard; dark theme; a phone width.
