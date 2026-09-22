# `timeline`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: ReUI "Timeline" (gap source); `steps` (progress
> through a process, not a history); `local_time_tag` and `avatar` (composed);
> `ai_chat_tool_call`'s `timeline:` join (AI chat only)

## Purpose

A list of things that happened, in order, joined by a line: an audit log, an
order's history, a deploy log, an activity feed with who did what, a roadmap of
milestones. Each event has a marker on the line, a title, an optional time and
an optional body.

It records history. It does not show where someone stands in a process they're
working through: use `steps` for that. For a table of log rows with columns,
use `table_for`.

## API

```erb
<%# The common case: dots, titles and times %>
<%= timeline do |timeline| %>
  <% @order.events.each do |event| %>
    <% timeline.event event.summary, time: event.created_at %>
  <% end %>
<% end %>

<%# The fuller case %>
<%= timeline label: "Deploy history", orientation: :vertical do |timeline| %>
  <% timeline.event "Deployed to production", time: deploy.finished_at, icon: :rocket, tone: :good,
                    href: deploy_path(deploy), description: "a1b2c3d by Keith" %>

  <% timeline.event "Keith commented", time: comment.created_at, avatar: comment.author.name do %>
    <%= simple_format comment.body %>
  <% end %>

  <% timeline.event "Build failed", time: build.failed_at, icon: :circle_x, tone: :bad do %>
    <%= code_view build.log_tail, max_height: "12rem" %>
  <% end %>

  <% timeline.event "Ships to customers", time: "Q4", pending: true %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `orientation:` | `:vertical`, `:horizontal` | `:vertical` | Validated. Horizontal lays out like vertical below 40rem |
| `label:` | String | `nil` | The list's `aria-label` |
| `marker:` | `:dot`, `:decimal`, `:lower_alpha`, `:upper_alpha`, `:lower_roman`, `:upper_roman` | `:dot` | Validated. CSS's `list-style-type` names. Anything but `:dot` draws the event's position, rendered by the server. An icon or avatar still wins |
| `skeleton:` | Boolean | `false` | Three placeholder events in a `status` group, in place of the block |

**Event options:**

| Option | Values | Default | Notes |
|---|---|---|---|
| title (positional) | String | required | Blank raises `ArgumentError` |
| `time:` | Time, Date, String, `nil` | `nil` | A Time or Date goes through `local_time_tag`; a String prints as it is (for "Q4", "v2.0", or markup such as a badge) |
| `time_format:` | a `local_time_tag` format | `:medium`, or `:date` for a Date | Passed through, so `:relative` gives "3 hours ago" |
| `icon:` | a Lucide symbol | `nil` | Draws the icon in a circle marker instead of the dot |
| `avatar:` | a name, or a Hash of `avatar` options | `nil` | `avatar: user.name` or `avatar: { name:, src: }`. Can't be combined with `icon:` |
| `tone:` | `:neutral`, `:good`, `:warn`, `:bad`, `:info` | `:neutral` | Validated. Colours the dot or icon marker |
| `pending:` | Boolean | `false` | Hasn't happened yet: hollow marker, dashed line into it, muted title |
| `href:` | URL | `nil` | Renders the title as a link |
| `description:` | String | `nil` | A second line under the title |
| block | markup | `nil` | The event's body: text, a card, a code view, buttons |

- **The order is the caller's.** Events render in the order they're given, so
  a feed sorted newest first reads newest first. The gem doesn't sort.
- **Other options** on `timeline` go on the `<ol>`. Other options on `event`
  go on its `<li>`.
- **No events** renders nothing (`nil`), so the caller can use
  `timeline(...).presence || empty_state(...)`.
- **Validation:** raised straight away: an unknown `orientation:` or `tone:`,
  a blank title, and `icon:` together with `avatar:`.

## Markup

```html
<ol class="UnmagicTimeline UnmagicTimeline--vertical" aria-label="Deploy history">
  <li class="UnmagicTimeline__event" data-tone="good">
    <span class="UnmagicTimeline__marker UnmagicTimeline__marker--icon" aria-hidden="true">
      <svg class="UnmagicIcon">…rocket…</svg>
    </span>
    <div class="UnmagicTimeline__content">
      <div class="UnmagicTimeline__header">
        <a class="UnmagicTimeline__title" href="/deploys/42">Deployed to production</a>
        <unmagic-time class="UnmagicTimeline__time" …><time datetime="…">22 Sept 2026, 4:33 pm</time></unmagic-time>
      </div>
      <p class="UnmagicTimeline__description">a1b2c3d by Keith</p>
    </div>
  </li>
  <li class="UnmagicTimeline__event" data-tone="neutral">
    <span class="UnmagicTimeline__marker UnmagicTimeline__marker--avatar" aria-hidden="true">
      <span class="UnmagicAvatar UnmagicAvatar--small …">KP</span>
    </span>
    <div class="UnmagicTimeline__content">
      <div class="UnmagicTimeline__header">…</div>
      <div class="UnmagicTimeline__body">…block…</div>
    </div>
  </li>
  <li class="UnmagicTimeline__event" data-tone="neutral" data-pending>
    <span class="UnmagicTimeline__marker UnmagicTimeline__marker--dot" aria-hidden="true"></span>
    <div class="UnmagicTimeline__content">
      <div class="UnmagicTimeline__header">
        <span class="UnmagicTimeline__title">Ships to customers</span>
        <span class="UnmagicTimeline__time">Q4</span>
        <span class="UnmagicVisuallyHidden">(upcoming)</span>
      </div>
    </div>
  </li>
</ol>
```

- **An `<ol>`**, because the order means something. There's no `<nav>`,
  because this isn't navigation.
- **The title is a `<span>` or `<a>`, not a heading.** The gem can't know the
  heading level around it, and a feed of 50 events shouldn't add 50 headings
  to the outline. A caller that wants headings puts them in the body.
- **The time comes after the title** in source order, so a screen reader reads
  "Deployed to production, 22 Sept 2026". It's placed at the end of the line
  visually.
- **The connector line** is CSS (`::before` on each event except the last),
  not an element.

## Accessibility

- **List semantics** carry the count and position ("list, 4 items").
- **Markers are `aria-hidden`.** Tone and icon are decoration. A `:bad` event's
  meaning belongs in its title ("Build failed"), and the note says so in the
  helper comment. There's no hidden "(error)" text, unlike `steps`, because a
  timeline event's title already says what happened.
- **Pending events** carry a visually hidden "(upcoming)", since a hollow dot
  alone doesn't reach a screen reader.
- **Times** are `<time datetime>` through `local_time_tag`, so the machine value
  is always there.
- **Keyboard:** nothing of its own. Linked titles and anything in the body are
  focusable in document order.

## Styling

CSS section: `Timeline`, placed after `Trees` (`Steps` is not built yet).

- **Elements:** `UnmagicTimeline` with `--vertical` and `--horizontal`,
  `__event`, `__marker` with `--dot`, `--icon`, `--counter` and `--avatar`, `__content`,
  `__header`, `__title`, `__time`, `__description` and `__body`.
- **State** comes from `[data-tone=…]` and `[data-pending]`, with no state
  classes.
- **Marker column:** a fixed 1.5rem column. Every marker is centred in it, so
  the line stays straight when dots, icons and avatars are mixed.
  - dot: 0.625rem, `neutral-400`/`dark:neutral-500`, or the tone's `500`/`dark:400`
  - icon: 1.5rem circle, `bg-white dark:bg-neutral-900` with a
    `neutral-200`/`dark:neutral-800` border and a `neutral-600`/`dark:neutral-400`
    icon. A tone tints all three: `50`/`dark:950` fill, `200`/`dark:400/20`
    border, `600`/`dark:400` icon, in green, amber, red or blue
  - counter: the icon's circle with `text-xs font-semibold` text, tinted by
    tone the same way. The counter is `aria-hidden`: the `<ol>` already gives
    the position
  - avatar: `avatar size: :small`, with a `white`/`dark:neutral-900` ring so
    the line doesn't run through it
  - pending: a hollow dot or icon ring with a dashed `neutral-300`/`dark:neutral-700` border
- **Connector:** 1px `neutral-200`/`dark:neutral-800`, running from under each
  marker to the next one. It's dashed on the stretch into a pending event.
- **Text:** title `text-sm font-medium neutral-900`/`dark:neutral-100`, `neutral-500` when
  pending. Time `text-xs neutral-500`, `tabular-nums`. Description `text-sm neutral-500`/`dark:neutral-400`.
  Body `text-sm`, `mt-2`.
- **Spacing:** `gap-3` between marker and content, `pb-6` between events, none
  after the last. Each event's grid packs to the top (`content-start`), so a
  horizontal row with one tall event keeps its markers in line.
- **Header:** the title grows from a 12rem basis and the time sits at the end
  of its line. When both don't fit, the time wraps under the title, left
  aligned. Content breaks long words (`wrap-break-word`), so a URL can't
  overflow.
- **Horizontal:** events sit side by side in equal columns, markers on one
  line along the top, and the text under each marker. It uses the same
  `@media (max-width: 40rem)` switch to the vertical layout as `steps`.
- **Motion:** none.
- **Forced colours:** the dots and the line get `CanvasText`, so they don't
  disappear.

## Small screens

- Horizontal becomes vertical below 40rem rather than scrolling sideways. A
  timeline is read, not scanned like a row of tabs.
- The header wraps. The time drops under the title when there's no room.
- Body content (code views, tables) keeps its own overflow rules.

## Behaviour (JavaScript)

_None: CSS and markup only._ Relative times keep themselves current through
`<unmagic-time>`, which `local_time_tag` already needs (import
`unmagic/components/time`).

## I18n

| Key | Default |
|---|---|
| `unmagic.components.timeline.pending` | "(upcoming)" |

## Specs

`spec/unmagic/components/timeline_spec.rb`:

- **Structure:** an `ol.UnmagicTimeline--vertical` with one
  `li.UnmagicTimeline__event` per event, in the given order.
- **Markers:** a `--dot` by default. `icon:` renders an `svg` in `--icon`.
  `avatar: "Ada Lovelace"` renders `.UnmagicAvatar` with "AL", and
  `avatar: { name:, src: }` renders an `img`. Every marker is `aria-hidden`.
- **Time:** a Time renders `unmagic-time` with `time[datetime]`. `time_format:`
  is passed through. A String renders as it is. `nil` renders no `__time`.
- **Tone and pending:** `data-tone` is set. `pending: true` sets `data-pending`
  and the hidden "(upcoming)".
- **Title:** `href:` renders `a.UnmagicTimeline__title`, otherwise a `span`.
- **Body and description** render only when given.
- **Empty:** a timeline with no events renders `nil`.
- **Validation:** an unknown `orientation:` or `tone:`, a blank title, and
  `icon:` with `avatar:` each raise `ArgumentError`.
- **Passthrough:** `class:`, `id:` and `data-*` on both the `<ol>` and each `<li>`.

## Preview

A `timeline` page in the component browser, with these examples:

- **Basic:** dots, titles and relative times
- **Order status:** tone icons (placed, paid, shipped, then a pending "delivered")
- **Activity feed:** avatars, with comment bodies
- **Deploy log:** icons, a failed step whose body is a `code_view`
- **Roadmap:** horizontal, string times ("Q1"…"Q4"), later quarters pending

**Check by hand:** the dark theme, a phone width (horizontal falling back to
vertical), mixed markers keeping the line straight, a long title wrapping, and
forced colours.

## Decisions from review

- **`marker:`** came after the first build, for an interview process laid out
  in steps. It borrows CSS's `list-style-type` names rather than adding a
  boolean. The server writes the counter (not CSS `counter()`), so it reads
  right before styles load. It draws the position the `<ol>` already carries.

- **`steps` stays its own component** with its own semantics (`<nav>`,
  `aria-current`). It may share the connector geometry in CSS when it's built.
- **No `busy:`** in v1. A running event can pass `icon: :loader_circle`.
- **No collapsible option.** Put a `disclosure` in the body.
- **No compact density** until a real feed asks for it.
- **`skeleton: true`** is built: three placeholder events, like `detail_list`
  and `card`.
