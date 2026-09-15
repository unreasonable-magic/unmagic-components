# `animated_number`

> Status: draft
> Tier: 2 (small element)
> Replaces or relates to:
> - Rails Blocks "Animated Number" (the gap source)
> - `local_time_tag`: the same shape of server rendering, then `Intl` formatting in the browser

## Purpose

A figure that counts to its value instead of appearing: a stat on a dashboard
card, a total that just changed after a live update. The motion says "this
changed". Its main job is to make a **new** value noticeable when a morph or
stream updates it.

It is **not** for figures in tables or forms, where movement is noise, and not
for money that must never appear mid-count as a wrong value to a screen reader.
The accessible value is always the final one.

## API

```erb
<%= animated_number @stats.signups %>
<%= animated_number @mrr, format: :currency, currency: "AUD" %>
<%= animated_number 0.873, format: :percent, from: 0, duration: 1200 %>
<%= animated_number @events, format: :compact %>                 <%# 12.4K %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `format:` | `:decimal`, `:currency`, `:percent`, `:compact` | `:decimal` | Validated. Maps to `Intl.NumberFormat` `style` / `notation` |
| `currency:` | ISO code | nil | Required with `:currency`, otherwise raises `ArgumentError` |
| `precision:` | integer | the value's own decimals | `maximumFractionDigits` |
| `from:` | number or nil | nil | nil means no animation on first render, only on later changes |
| `duration:` | ms | 800 | Clamped to 0..3000 |

- A blank value renders an em dash with no element.
- Other options go on the element.
- `animated_number` never guesses a locale. The browser formats with the
  page's `lang`, or the viewer's language when there is none, as
  `local_time_tag` does.

## Markup

```html
<unmagic-number class="UnmagicNumber" value="1204" format="decimal" from="0" duration="800">
  <span class="UnmagicNumber__display" aria-hidden="true">1,204</span>
  <span class="UnmagicVisuallyHidden">1,204</span>
</unmagic-number>
```

- **Server rendering:** Ruby formats the final value (`number_with_delimiter`,
  `number_to_currency`, `number_to_percentage`, `number_to_human`) in
  `I18n.locale`. The page reads correctly before upgrade and without script.
- **Two spans:** the visible span animates, and the hidden span always holds
  the final value, so a screen reader never hears the intermediate numbers.

## Accessibility

- **No ARIA widget pattern:** it is static text.
- **The display is `aria-hidden`.** The visually hidden span carries the final
  formatted value, and script updates it once, when the value changes.
- **Changes aren't announced.** Wrap the number in the host's own live region
  when an announcement is wanted, because a dashboard of counters shouldn't
  talk.
- **No keyboard interaction and no focus.**
- **Reduced motion:** the final value is set at once.

## Styling

- **CSS section `Animated numbers`:**
  - `UnmagicNumber { font-variant-numeric: tabular-nums; }`, so digits don't
    jitter
  - `display: inline-block`
  - `min-width` fixed by script to the widest of the start and end strings, in
    `ch`, while animating, so surrounding text doesn't shift
- **State:** `[data-animating]` is available to hosts, but the gem doesn't
  style it.
- **No colour** of its own; it inherits the text colour.

## Behaviour (JavaScript)

`<unmagic-number>` in `animated_number.js`. It reads `value`, `format`,
`currency`, `precision`, `from` and `duration`
(`static observedAttributes = ["value"]`).

- **Formatting:**
  - a single `Intl.NumberFormat` per element, built on connect from
    `document.documentElement.lang || navigator.language`
  - `:compact` means `notation: "compact"`
  - fraction digits are fixed to the final value's, so a count to 12.50 shows
    two decimals throughout
- **First render:**
  - with `from` present, and the element not already `data-played`, it waits
    until the element is 50% visible (IntersectionObserver), then animates
    `from → value` and sets `data-played`
  - without `from` it just reformats the final value with `Intl`
- **Later changes** (`attributeChangedCallback` for `value`): it animates from
  the currently displayed number to the new value. That covers both a morph and
  script setting `value`.
- **Frames:**
  - `requestAnimationFrame`, easing with ease-out cubic
  - a new target mid-animation starts again from the current displayed number
  - the hidden span is updated once, at the start
  - it fires `unmagic-number:change` with `{ from, to }` when finished
- **Reduced motion** (`matchMedia("(prefers-reduced-motion: reduce)")`): the
  final value is written immediately and no frames are scheduled.

Turbo:
- **Cache:** on `turbo:before-cache` it cancels the frame and writes the final
  value, so the snapshot holds the real number and never a mid-count one.
- **Snapshot clones:** a restored clone carries `data-played`, so it doesn't
  count up from `from` again. The server-rendered spans are the only DOM, and
  nothing is generated.
- **Morph:** Idiomorph keeps the element and updates its `value` attribute,
  which animates old → new. Idiomorph also rewrites the spans' text to the
  server's final value. The animation keeps writing over the display span on
  following frames, which is fine because both end on the same value.
- **Streamed content:** `turbo_stream.replace` inserts a new element without
  `data-played`. With `from` it animates from `from`, without it no count
  happens. For "count old → new" updates, streams should use
  `turbo_stream.update` on a wrapper and change `value`, or the page should
  rely on morph. The README says so.
- **Cleanup:** `disconnectedCallback` cancels the frame and disconnects the
  observer.

Dependencies: none, and it doesn't need Turbo.

## I18n

None. `Intl` and Rails' number helpers use the locale.

## Specs

In `time_and_tooltip_spec.rb`, or a new `animated_number_spec.rb`:
- Renders `unmagic-number.UnmagicNumber[value][format]`, with an
  `aria-hidden` display span and a visually hidden span, both holding the
  server-formatted final value.
- The server formatting covers each format:
  - `1204` becomes "1,204"
  - `:currency` with AUD
  - `0.873` as a percent
  - `12_400` compact becomes "12.4K"
- `from:` and `duration:` render as attributes, and `duration` is clamped.
- A blank value renders "—" with no element.
- An unknown `format:` raises `ArgumentError`, and so does `:currency` without
  `currency:`.
- `class:` passes through.

## Preview

On `elements`: a row of stat cards (`card`) with `from: 0`, and a button that
streams or morphs new values.

Hand checks:
- The count starts when scrolled into view.
- A morph refresh with a new value animates old → new.
- Reduced motion (DevTools emulation) jumps straight to the value.
- VoiceOver reads only final values.
- Back and then Forward don't recount.
- `lang="de"` on the preview layout formats as "1.204".
- Check dark mode.

## Open questions

- **Locale:** should the browser format with the page's `lang` (proposed) or
  the viewer's language? `local_time_tag` uses the viewer's. Numbers in an
  app's own language may read better.
- **Negative values:** should an animated change get a `good` or `bad` flash
  tint (up or down)? Proposed: no, but a documented event lets hosts do it.
