# `scroll_area`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Scroll Area" (gap source). Useful inside `card flush:`, `dialog` bodies and `sidebar`.

## Purpose

A container with a bounded height or width that scrolls:
- a thin, themed scrollbar
- a reserved gutter so content doesn't jump
- shadows at the edges that show there is more to scroll

Use it for a long list in a card or a wide `table_tag`.

It is not a replacement for page scrolling, and it doesn't draw a custom
JS-driven scrollbar.

**Placement:** core CSS. It is a small application-UI primitive.

## API

```erb
<%= scroll_area max_height: "20rem" do %>
  <ul>…long list…</ul>
<% end %>

<%= scroll_area axis: :x, label: "Pipeline stages" do %>…wide board…<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `axis:` | `:y`, `:x`, `:both` | `:y` | Validated |
| `max_height:` | CSS length | none | Sets the `--unmagic-scroll-area-max-height` knob via `style:` |
| `label:` | string | none | When given: `role="region"`, `aria-label`, `tabindex="0"` |
| `shadows:` | boolean | `true` | Edge fade indicators |

- Other options go on the `<div>`.
- With no `max_height:` the height comes from the host's layout (e.g. a flex
  child).

## Markup

```html
<div class="UnmagicScrollArea UnmagicScrollArea--y UnmagicScrollArea--shadows"
  style="--unmagic-scroll-area-max-height: 20rem" role="region" aria-label="Pipeline stages" tabindex="0">
  …content…
</div>
```

## Accessibility

- **Keyboard scrolling.** A scrollable region with no focusable content needs
  a `tabindex="0"` and a name to be keyboard-scrollable (axe rule
  `scrollable-region-focusable`). `label:` provides both.
- **Without `label:`** there is no role or tabindex. The note advises passing
  `label:` whenever the content has no links or buttons.
- **Focus:** `:focus-visible` outline, inset, so it isn't clipped.

## Styling

- **Section:** `Scroll area`.
- **Modifiers:** `--y`, `--x`, `--both`, `--shadows`.
- **Base:**
  - `overflow: auto` on the chosen axis
  - `max-height: var(--unmagic-scroll-area-max-height, none)`
  - `scrollbar-gutter: stable`
  - `scrollbar-width: thin`
  - `scrollbar-color: var(--unmagic-border-strong, …) transparent`
  - `overscroll-behavior: contain`
- **Shadows are CSS only**, using the scroll-bound background technique: two
  `background-attachment: local` covers in `surface` over two
  `background-attachment: scroll` radial shadows. The shadows show only where
  content is hidden, with no script.
- **Tokens:** the existing `surface`, `border-strong` and `focus`; there is no
  new theme token.
  - The shadow covers use `--unmagic-surface`, so they match a container on the
    surface colour.
  - A scroll area on a different background sets `--unmagic-surface` on itself
    through `style:` or a host class.
- **Knob:** `--unmagic-scroll-area-max-height` is a per-instance knob
  (`--unmagic-<component>-<property>`), written through `style:` by
  `max_height:`. It is documented in the README section, never listed under
  Theming.

## Behaviour (JavaScript)

_None._ Scroll position across Turbo morphs is the host's concern
(`turbo_refresh_scroll_tag` and `data-turbo-permanent`).

## I18n

None.

## Specs

- Classes appear per `axis:`.
- `max_height:` becomes the style custom property.
- `label:` adds `role`, `aria-label` and `tabindex`; without it none of those
  appear.
- `shadows: false` drops the modifier.
- `ArgumentError` for `axis: :z`.
- `class:` and `style:` merge.

## Preview

- **Page:** `primitives`, with a vertical list in a card and a horizontal wide
  table.
- **Hand-check:**
  - Shadows appear and disappear at the ends.
  - Keyboard focus, then arrow keys, scroll.
  - Dark mode: the covers match the surface.
