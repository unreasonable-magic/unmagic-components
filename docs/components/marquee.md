# `marquee`

> Status: draft
> Tier: marketing
> Replaces or relates to: Rails Blocks "Marquee" (gap source). No existing component.

## Purpose

A row of content that scrolls sideways on a loop: customer logos, a strip of
short quotes, "trusted by" rows on a landing or sign-in page.

Not for anything a user must read in order to act. Status messages belong in a
`callout` or a toast, and navigation belongs in `tabs` or `navbar`.

**Placement (decided):** a core `Marquee` section in `components.css`, shipped
like every other component. Marketing-style components live in the core
stylesheet.

## API

```erb
<%= marquee label: "Customers" do |m| %>
  <% m.item { image_tag "logos/acme.svg", alt: "Acme" } %>
  <% m.item { image_tag "logos/globex.svg", alt: "Globex" } %>
<% end %>

<%= marquee direction: :reverse, speed: :slow, fade: false do |m| %>…<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | none | `aria-label` on the region |
| `direction:` | `:forward`, `:reverse` | `:forward` | Validated |
| `speed:` | `:slow`, `:medium`, `:fast` | `:medium` | Validated; sets the CSS duration |
| `fade:` | boolean | `true` | Masks the edges |

- `m.item` takes a block or a string.
- Other options go on the root element.
- With no items, nothing renders (`nil`).

## Markup

```html
<unmagic-marquee class="UnmagicMarquee UnmagicMarquee--forward UnmagicMarquee--medium UnmagicMarquee--fade"
  role="region" aria-label="Customers">
  <ul class="UnmagicMarquee__track">
    <li class="UnmagicMarquee__item">…</li>
  </ul>
  <ul class="UnmagicMarquee__track" aria-hidden="true" inert>…the same items…</ul>
</unmagic-marquee>
```

- **Ruby renders the duplicate track itself**, so the loop is seamless with no
  script. The copy carries `aria-hidden="true"` and `inert`, so screen readers
  and the tab order see each item once.
- **The animation is pure CSS**: `@keyframes` translating each track by
  `-100%`.

## Accessibility

- A labelled `region`, holding a list.
- The duplicate track is hidden and inert.
- **The animation stops under `prefers-reduced-motion: reduce`.** The first
  track then wraps (`flex-wrap`) so every item stays visible, and the duplicate
  is `display: none`.
- **Hovering or focusing inside the marquee pauses it**
  (`:hover, :focus-within { animation-play-state: paused }`). This meets WCAG
  2.2.2 (pause, stop, hide) for pointer and keyboard users.
- A pause button isn't needed, because the content is decorative. See the open
  questions.

## Styling

- **Section:** `Marquee`.
- **Elements:** `__track`, `__item`.
- **Modifiers:** `--forward`/`--reverse`, `--slow`/`--medium`/`--fast`
  (40s/25s/15s via `--unmagic-marquee-duration`), and `--fade`, which uses
  `mask-image` with a linear gradient.
- **Gap:** `--unmagic-marquee-gap`, falling back to 3rem.
- **Knobs, not theme tokens.** `--unmagic-marquee-duration` and
  `--unmagic-marquee-gap` are per-instance knobs (`--unmagic-<component>-<property>`).
  The modifiers set them, or a caller can set them with `style:`. They're
  documented in the component's README section and never listed under
  Theming.
- **Colour:** it uses no colour tokens; it inherits colour.

## Behaviour (JavaScript)

_None: CSS and markup only._ The element name is a plain tag, so `:defined`
isn't needed. The `unmagic-marquee` tag is kept so a later version can add
script without a markup change.

- **Turbo:** nothing to do. A snapshot restores a running CSS animation.

## I18n

None. The caller supplies the label.

## Specs

- Two tracks render; the second is `aria-hidden` and `inert`, and it holds the
  same number of items.
- The modifier classes appear for `direction:`, `speed:` and `fade:`.
- `label:` becomes `aria-label`.
- `class:` and other attributes pass through to the root.
- `ArgumentError` for an unknown `direction:` or `speed:`.
- No items renders nothing.

## Preview

- **Page:** a new `marketing` page (a route, an action and a nav link),
  showing logo and quote marquees in both directions.
- **Hand-check:**
  - Hover pauses it.
  - Tabbing into a link inside pauses it.
  - With reduced motion, items wrap and are static.
  - A screen reader reads each item once.
  - It looks right in dark mode.

## Open questions

- Should `pause_button: true` add a visible pause control for marquees with
  meaningful content?
