# `progress`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `spinner` (waiting with no fraction to show),
> `ai_chat_tool_call`'s progress row

## Purpose

A bar filled to a fraction of the way: an upload, a render queue, a quota.
When there is no fraction yet, it sweeps.

## API

```erb
<%= progress 42 %>
<%= progress 3, max: 8, tone: :good, label: "Uploaded" %>
<%= progress indeterminate: true, label: "Preparing" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `value` (positional) | Number or `nil` | `nil` | Clamped to `0..max`; `nil` is indeterminate |
| `max:` | Positive number | `100` | Validated |
| `tone:` | `:neutral`, `:good`, `:warn`, `:bad`, `:info` | `:neutral` | Validated |
| `size:` | `:small`, `:medium`, `:large` | `:medium` | Validated |
| `label:` | String | I18n "Progress" | The accessible name |
| `indeterminate:` | Boolean | `false` | Sweeps instead of filling |

Other options go on the bar.

## Markup

```html
<div role="progressbar" aria-label="Uploaded" aria-valuemin="0" aria-valuemax="8" aria-valuenow="3.0" class="UnmagicProgress UnmagicProgress--medium UnmagicProgress--good">
  <div class="UnmagicProgress__bar" style="width: 37.5%"></div>
</div>
```

A div with the role rather than `<progress>`, whose look no two browsers agree
on and whose indeterminate state can't be restyled.

## Accessibility

The progressbar role with min, max and now; no `aria-valuenow` while
indeterminate, which is what the role means by it.

## Styling

Section **Progress**: sizes by height, tones by the bar's colour, the width
transitions so a live update slides. `--indeterminate` sweeps a third of the bar
across; under reduced motion it pulses in place.

## Small screens

Full width by default. Nothing else to do.

## Behaviour (JavaScript)

None.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.progress.label` | "Progress" |

## Specs

`spec/unmagic/components/buttons_spec.rb`.
