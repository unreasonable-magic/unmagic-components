# `<unmagic-elapsed>`

> Status: built
> Tier: 2 (small element)
> Relates to: `local_time_tag`, which formats an instant rather than a duration

## As built

Where the build differs from this note:

- The `title` is the start (or end) time in `I18n.l(time, format: :long)`.

## Purpose

A clock counting up from a moment the server named, a second at a time. Work
that takes a minute and work that has quietly hung look identical behind a
spinner; a number that keeps moving is the whole difference between them.

For anything in flight whose duration is worth watching: a tool call, an import,
a deploy. Not for a settled duration — that is a string the server already knows
and should just print.

It comes from toybox, where a running tool call counts up and a finished one
says what it took, both in the same words.

## API

```erb
<%# The server draws the first reading; the element keeps it moving %>
<%= elapsed_tag tool_call.started_at %>

<%# Counting down to a deadline instead %>
<%= elapsed_tag session.expires_at, direction: :down %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `direction:` | `:up`, `:down` | `:up` | Validated; raises `ArgumentError` |

- Other options go on the root element.
- A `nil` instant renders an em dash and no element, as `local_time_tag` does.
- A `:down` clock that reaches zero stops at `0s` and fires its event.

The helper renders the current reading server-side, so the element already says
the right thing before its script loads — the philosophy's first rule.

## Markup

```html
<unmagic-elapsed since="2026-09-16T12:00:00.000Z" class="UnmagicElapsed">3m 5s</unmagic-elapsed>
```

`:down` renders `until` in place of `since`. The instant is ISO 8601 with
milliseconds, in UTC, so the browser's clock and the server's agree about the
origin even where the two disagree about now.

## Accessibility

- The element is not a live region. A number changing every second and announced
  every second is unusable; the reading is there for whoever looks.
- Where the duration genuinely matters to a non-visual reader — a call that has
  been running a long time — that is the surrounding component's job to announce
  once, not this element's to announce sixty times.
- The element carries a `title` with the absolute start time, so the origin is
  recoverable.

## Styling

CSS section: **Elapsed**.

```css
.UnmagicElapsed { @apply font-mono text-xs tabular-nums; }
```

`tabular-nums` is the whole point of styling it at all: without it the reading
shifts sideways every time a digit changes width, and a row of them shimmers.

No colours — the caller's context supplies those. No motion, so nothing for
`prefers-reduced-motion` to switch off.

## Behaviour (JavaScript)

`<unmagic-elapsed>` — reads `since` or `until`.

- A one-second interval rewrites `textContent` with the same words the Ruby
  helper writes, so a running reading and a settled one are indistinguishable.
  The formatting rule lives in both places and the note for each says so.
- Whole seconds, floored rather than rounded: a stopwatch says how long it has
  been, not how long it nearly has been.
- Anything under a second is milliseconds (`640ms`), then `2s`, `3m 5s`,
  `1h 4m 2s`. Units that would read as zero are left off — this is prose about a
  wait, not a clock.
- Fires `unmagic-elapsed:end` when a `:down` clock reaches zero.
- Turbo:
  - The interval starts in `connectedCallback` and is cleared in
    `disconnectedCallback`, so a replaced element leaves no timer behind. A tool
    call redrawn on every state change replaces this element constantly.
  - `observedAttributes` covers `since` and `until`, so a redraw that changes
    the origin is picked up without a reconnect.
  - Needs no Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.elapsed.milliseconds` | "%{count}ms" |
| `unmagic.components.elapsed.seconds` | "%{count}s" |
| `unmagic.components.elapsed.minutes` | "%{minutes}m %{seconds}s" |
| `unmagic.components.elapsed.hours` | "%{hours}h %{minutes}m %{seconds}s" |

The JavaScript can't read these, which is the one place this component's two
halves can disagree. Noted rather than solved: an application that translates
these also has to hand the element its own formats, and there is no case for
that yet.

## Specs

`spec/unmagic/components/elapsed_spec.rb`:

- The server-rendered reading for each band (ms, s, m, h).
- `since` vs `until` for each direction.
- `ArgumentError` for an unknown direction.
- An em dash for `nil`.
- Passthrough `class:` and attributes on the root.

## Preview

Page: `elements`. A row of clocks started at different offsets — one seconds
old, one minutes, one hours — plus a countdown with a few seconds left so its
end can be watched.

By hand: the readings climb; the countdown stops at zero; navigating away and
back leaves no runaway timers (check the console for a growing interval count).

## Open questions

- Should a long-running clock slow its tick? A call at four hours does not need
  a redraw every second. Proposed: no. The complexity is not worth it, and a
  four-hour tool call is a bug worth watching tick.
