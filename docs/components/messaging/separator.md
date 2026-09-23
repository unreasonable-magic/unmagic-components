# `message_separator`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `separator` (a rule with a word; this one is dated and
> sits in a thread), `local_time_tag`

## Purpose

A line across a conversation that says when the messages after it were sent
("Today", a date), or that they are new. Every chat client groups a thread by
day this way.

## API

```erb
<%= message_separator "Today" %>
<%= message_separator time: Date.new(2026, 9, 12) %>
<%= message_separator unread: true %>
<%= message_separator "3 new messages", unread: true %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| label (positional) | string | `nil` | Printed as it is |
| `time:` | Time, Date | `nil` | Through `local_time_tag` with `format: :date`; the label wins when both are given |
| `unread:` | boolean | `false` | Marks the line as the start of what's new, with "New messages" if there's no label |

With neither a label nor a time nor `unread:` it renders a plain line. Other
options go on the `<div>`.

## Markup

```html
<div class="UnmagicMessageSeparator"><span class="UnmagicMessageSeparator__label">Today</span></div>
<div class="UnmagicMessageSeparator" data-unread=""><span class="UnmagicMessageSeparator__label">New messages</span></div>
```

A `<div>` with a label, not `role="separator"`: a separator's children are
presentational, so its label would be silent, and in a log the date is
something a reader should hear before the messages it dates.

## Accessibility

- The label is read in flow, as text.
- `time:` is a `local_time_tag`, so it reads in the viewer's zone.
- Unread is a word ("New messages") as well as a colour.

## Styling

CSS section: **Message separators**.

- `.UnmagicMessageSeparator`, `__label`, `[data-unread]`
- `flex items-center gap-3 text-xs text-neutral-500 dark:text-neutral-400`,
  drawing the line either side of the label with `::before` and `::after`
  (`h-px flex-1 bg-neutral-200 dark:bg-neutral-800`), as `separator` does.
- `[data-unread]`: label `font-medium text-blue-600 dark:text-blue-400`, lines
  `bg-blue-300 dark:bg-blue-500/40`. Blue, because new is information, not a
  fault.
- Motion: none.

## Small screens

Nothing of its own.

## Behaviour (JavaScript)

_None._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.message.separator.unread` | "New messages" |

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- A label renders in the span; `time:` renders an `<unmagic-time format="date">`;
  a label beats a time.
- `unread: true` sets `data-unread` and the default label.
- Nothing given renders the bare line; passthrough `class:`.

## Preview

Page: `message_separator`. A dated line, "Today", and an unread marker, between
messages.

By hand: dark theme.

## Open questions

- Sticky dates: see the family README.
