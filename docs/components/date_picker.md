# `date_picker`

> Status: draft
> Tier: 3 (large)
> Replaces or relates to: the gap source is Rails Blocks "Date Picker". Relates to `local_time_tag` (`local_time.rb`, `time.js`) and `FormBuilder#field`.

## Decision: enhance the native input, don't replace it

**Recommendation: build a thin enhancement of `<input type="date">` and
`<input type="datetime-local">`. Do not build a custom calendar grid.**

Why:
- **Principle 2 (native elements first).** Every evergreen browser ships a
  date input with a localised, accessible calendar, and the mobile ones are
  far better than any grid we could draw.
- **The risks of a custom grid:**
  - the APG date picker dialog pattern is a large keyboard surface (days,
    weeks, months, years, and focus trapping)
  - week start and numbering vary by locale
  - calendars other than the Gregorian one
  - right-to-left layouts
  - the maintenance that follows from all of these
- **What apps actually miss** isn't the calendar. It's four things the native
  input doesn't give:
  1. quick presets ("Today", "Next Monday")
  2. a clear button
  3. a range whose end can't precede its start
  4. a `datetime-local` that means the **viewer's** time zone, the way
     `local_time_tag` does, rather than silently meaning `Time.zone`

Revisit a custom grid only if an app needs one of these:
- a range drawn across one calendar
- disabled arbitrary dates (not only `min` and `max`)
- availability shown on days

It would then be its own note, following the
[APG date picker dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/examples/datepicker-dialog/).

## Purpose

This picks a date or a date and time in a form, with shortcuts for common
choices, and pairs start and end fields. It is **not** for display (use
`local_time_tag`) or for scheduling UIs with availability.

## API

```erb
<%= form.field :due_on, "Due", as: :date_picker, presets: %i[today tomorrow next_week], clear: true %>

<%= form.field :starts_at, "Starts" do %>
  <%= form.date_picker :starts_at, time: true, zone: :viewer %>
<% end %>

<%= form.date_range :starts_on, :ends_on, labels: [ "From", "To" ] %>

<%= date_picker_tag "due_on", params[:due_on], min: Date.current %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `time:` | boolean | `false` | `datetime-local` instead of `date` |
| `zone:` | `:server`, `:viewer` | `:server` | `:viewer` needs `time: true`; validated |
| `presets:` | array of preset symbols | `[]` | `:today`, `:tomorrow`, `:next_week`, `:end_of_month`, validated |
| `clear:` | boolean | `false` | A button that empties the input |
| `min:`, `max:` | Date/Time | `nil` | Passed to the input |

- **`zone: :server`** is plain Rails. The input submits wall-clock time, read
  in `Time.zone`, and no script is needed.
- **`zone: :viewer`:**
  - The visible input has no name. A hidden input named for the attribute
    holds a UTC ISO 8601 value, which the element converts to and from the
    viewer's zone.
  - Without script the hidden input keeps the server value, so the record is
    unchanged.
  - This matches `local_time_tag`, which also shows the viewer's zone.
- **`date_range(start, end, labels:, **options)`** renders both pickers in a
  `group` and links them: the end's `min` follows the start, and the start's
  `max` follows the end.
- **Options:**
  - `required:` and `aria-invalid` go on the visible input.
  - Other options go on `<unmagic-date-picker>`.
- **A blank value** renders an empty input. Presets still work.

## Markup

```html
<unmagic-date-picker class="UnmagicDatePicker" zone="viewer">
  <div class="UnmagicDatePicker__control">
    <input type="datetime-local" id="event_starts_at" class="UnmagicDatePicker__input"
           value="2026-09-16T14:30" data-server-value="2026-09-16T04:30:00Z">
    <button type="button" class="UnmagicDatePicker__clear" aria-label="Clear" data-unmagic-date-clear>…x…</button>
  </div>
  <input type="hidden" name="event[starts_at]" value="2026-09-16T04:30:00Z">
  <div class="UnmagicDatePicker__presets" role="group" aria-label="Quick picks">
    <button type="button" class="UnmagicDatePicker__preset" data-preset="today">Today</button>
    <button type="button" class="UnmagicDatePicker__preset" data-preset="tomorrow">Tomorrow</button>
  </div>
</unmagic-date-picker>
```

- **The server renders the visible value in `Time.zone`**, so it reads
  correctly before the upgrade, as `local_time_tag`'s fallback does. The
  element rewrites it into the viewer's zone on connect.
- **Presets are computed in the browser**, in the viewer's zone, so "Today"
  near midnight means the viewer's today.

## Accessibility

- **The native input** supplies the calendar, its keyboard and its
  announcements.
- **Presets** are a labelled `role="group"` of buttons. Choosing one moves no
  focus, and a polite status announces the new value
  ("Due set to 17 September 2026"), formatted with Intl like `time.js`.
- **The clear button** is named "Clear" (plus the field label via
  `aria-describedby`). It is hidden while the input is empty.
- **A range violation** (end before start) sets `setCustomValidity` on the end
  input with a worded message, so native validation reports it.

| Key | Does |
|---|---|
| (native) | Everything inside the date input |
| Tab | Input, then clear, then each preset |
| Enter / Space | On a preset or clear: applies it |

## Styling

Section `/* Date pickers */`.

- **Elements:** `UnmagicDatePicker`, `__control`, `__input`, `__clear`,
  `__presets`, `__preset`. `UnmagicDateRange` is a row, reusing
  `UnmagicFieldGroup`.
- **Presets** look like small ghost buttons; they reuse `button_classes(:ghost, size: :small)`
  in Ruby rather than new CSS.
- **Control:**
  - The visible input gets `config.control_class.call(view, :date)`
    (`UnmagicInput` by default), so it matches the gem's other inputs.
  - `::-webkit-calendar-picker-indicator` is tinted `text-3` and nothing
    more, because the native calendar is kept.
  - The clear button sits inside the control's right padding.
- **State:** `__clear[hidden]`. Validity is styled by the host's own
  `:invalid` styles.
- **Tokens:** `text-3` for the clear icon. No new tokens.
- **Motion:** none.

## Behaviour (JavaScript)

`date_picker.js` defines `<unmagic-date-picker>`.

- **`zone="viewer"`:**
  - On connect, it converts `data-server-value` (UTC) into local
    `YYYY-MM-DDTHH:mm` for the visible input.
  - On `input`, it writes the UTC ISO value to the hidden input.
  - Date-only pickers ignore zone (a date has no zone).
- **Presets:** each computes a local `Date`, writes the input value, and
  dispatches `input` and `change`.
- **Clear:** empties both inputs and dispatches the events.
- **Range:** `date_range` wraps both pickers in `<unmagic-date-range>`, which
  listens for `change` and keeps `min` and `max` in step.
- **Form `reset`:** restores the visible input from `data-server-value`.
- **Events:** `unmagic-date-picker:change`, with `detail: { value }` (an ISO
  string or `""`).
- **Turbo:**
  - `turbo:before-cache`: restore the visible and hidden values from
    `data-server-value`, so a snapshot doesn't carry unsaved edits in an
    inconsistent zone.
  - `turbo:morph`: a morph may reset `data-server-value` and the visible
    value to the server's `Time.zone` rendering, so the zone conversion is
    re-run (listen for `turbo:morph`, as `tabs.js` does).
  - Snapshot clones: conversion is idempotent. Always derive from
    `data-server-value`, never from the visible value.
  - Streamed in: converts on connect.
- **Dependencies:** none. Turbo is not needed.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.date_picker.clear` | "Clear" |
| `unmagic.components.date_picker.presets` | "Quick picks" |
| `unmagic.components.date_picker.today` | "Today" |
| `unmagic.components.date_picker.tomorrow` | "Tomorrow" |
| `unmagic.components.date_picker.next_week` | "Next week" |
| `unmagic.components.date_picker.end_of_month` | "End of month" |
| `unmagic.components.date_picker.set` | "%{label} set to %{value}" |
| `unmagic.components.date_picker.range_invalid` | "Must be on or after %{start}" |

## Specs

`spec/unmagic/components/date_picker_spec.rb`:

- **Inputs:** `type=date` by default; `datetime-local` with `time: true`.
  `min` and `max` are formatted.
- **`zone: :viewer`:**
  - the visible input has no name, and the hidden input has the name and a UTC
    ISO value
  - `data-server-value`
  - the visible value is rendered in `Time.zone`
- **Presets and clear:** a button per preset with `data-preset`, a labelled
  group, and the clear button's label.
- **`as: :date_picker` inside `field`:** `required` and `aria-invalid` land on
  the visible input.
- **Control class seam:** the visible input carries the control class
  (`UnmagicInput` by default, replaced or dropped through `control_class`).
- **`date_range`:** two pickers inside `<unmagic-date-range>`, with labels.
- **`ArgumentError`:** an unknown preset, an unknown zone, and `zone: :viewer`
  without `time: true`.

## Preview

On the Forms page (or `primitives`):
- a date with presets and clear
- a `datetime-local` with `zone: :viewer`, next to a `local_time_tag` of the
  saved value
- a date range
- a form that shows the submitted params

Check by hand:
- Set the machine's time zone different from the preview's `Time.zone`. The
  saved viewer-zone time and `local_time_tag` agree.
- A preset near midnight picks the viewer's day.
- An end before the start blocks the submit with the message.
- Reset restores values; Turbo back doesn't show a shifted time.
- Keyboard through the presets; dark theme.

## Open questions

1. **Is `zone: :viewer` the right default for `time: true`?** It is safer for
   distributed teams, but it changes what the controller receives (an ISO UTC
   string, not wall-clock time).
2. **Presets:** is a fixed list enough, or should apps pass their own
   (`presets: { "In 2 weeks" => ->(today) { today + 14 } }`)? The lambda would
   have to run in the browser, so custom presets would need to be date
   offsets.
3. **Confirm no custom calendar** in this round.

## Comparison with the native input

| | Native `<input type=date / datetime-local>` | Custom calendar grid (replace) | This note (enhance) |
|---|---|---|---|
| **What users gain** | A familiar operating system calendar; typing a date segment by segment | A styled grid matching the app, ranges drawn in one calendar, disabled arbitrary days | Presets, clear, linked ranges, times in the viewer's zone consistent with `local_time_tag` |
| **Accessibility** | Built into the browser, and screen-reader tested | High cost: the APG date picker dialog means focus trapping, day, week, month and year keys, and grid announcements, all ours to get right and to test by hand (there are no JS tests) | No cost: the native input is untouched, and additions are plain buttons and a status region |
| **Mobile** | The operating system's wheel or calendar sheet, which is the best available | Worse: a small-target grid in a popover, fighting the virtual keyboard | Native sheet kept |
| **Locale** | Date order, month names and week start come from the browser and operating system | We would own week start, month and day names (Intl can supply them), right-to-left layout and non-Gregorian calendars | Browser-owned; preset announcements use Intl |
| **JS and data** | None | Roughly 10–15 KB of element code, plus CSS for the grid | About 2–3 KB of element code, and no data |

**Recommendation: enhance.** A custom grid's gains are real only for
availability or range-in-one-calendar UIs, which most apps don't have, and it
costs a lot in accessibility, mobile behaviour and locale handling. The
enhancement gives most of what users actually miss for a fraction of the
weight.
