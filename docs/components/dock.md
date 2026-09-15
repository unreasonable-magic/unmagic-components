# `dock`

> Status: draft
> Tier: marketing
> Replaces or relates to: Rails Blocks "Dock Menu" (gap source). Items reuse `tooltip` for labels.

## Purpose

A floating bar of icon links that magnifies the one under the pointer, like the
macOS dock. Good for a portfolio, a landing page or a playful app launcher.

Not for primary application navigation. Use `navbar` or `sidebar`, whose text
labels are always visible.

**Placement (decided):** a core `Dock` section in the gem's Tailwind `engine.css`, with its
script in `components/dock.js`, shipped like every other component.
Marketing-style components live in the core stylesheet.

## API

```erb
<%= dock label: "Quick links", position: :bottom do |dock| %>
  <% dock.link "Home", root_path, icon: home_svg, current: true %>
  <% dock.link "Mail", mail_path do %><%= inline_svg "mail" %><% end %>
  <% dock.divider %>
  <% dock.button "Settings", icon: gear_svg, data: { unmagic_dialog_open: "settings" } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | "Dock" (I18n) | `aria-label` on the `<nav>` |
| `position:` | `:inline`, `:bottom` | `:inline` | `:bottom` fixes it centred at the foot of the viewport |
| `magnify:` | boolean | `true` | `false` renders a static bar |

- `link(name, url, icon:, current:)` and `button(name, icon:, **attrs)` take
  the icon as `icon:` markup or a block.
- `name` is the accessible label and the tooltip text.
- `divider` adds a separator.

## Markup

```html
<unmagic-dock class="UnmagicDock UnmagicDock--bottom" magnify>
  <nav aria-label="Quick links">
    <ul class="UnmagicDock__list">
      <li class="UnmagicDock__item">
        <unmagic-tooltip text="Home" placement="top">
          <a class="UnmagicDock__action" href="/" aria-label="Home" aria-current="page">…svg…</a>
        </unmagic-tooltip>
      </li>
      <li class="UnmagicDock__divider" role="separator"></li>
    </ul>
  </nav>
</unmagic-dock>
```

Labels reuse `tooltip`, which is already top-layer and keyboard-accessible.
Without script it is a plain row of icon links with tooltips.

## Accessibility

- A labelled `<nav>` containing a list of links.
- Each icon-only action has `aria-label`, and its tooltip gives sighted users
  the same name.
- `aria-current="page"` marks the current link, which also shows a dot below
  it.
- The keyboard uses normal Tab order, not a roving `tabindex`: a dock is
  navigation, not a composite widget. Focus scales the item the same way hover
  does.
- **Reduced motion:** there is no magnification and no transitions.

## Styling

- **Section:** `Dock`.
- **Elements:** `__list`, `__item`, `__action`, `__divider`.
- **Modifiers:** `--bottom`.
- **Magnification** is `transform: scale(var(--unmagic-dock-scale, 1))` on the
  action, `transform-origin: bottom`, with a 150ms transition.
  `--unmagic-dock-scale` is a per-instance knob written by the script, not a
  theme colour.
- **Current state** is driven by `[aria-current="page"]`.
- **Colours:** `white/80`/`dark:neutral-900/80` (with `backdrop-filter` blur),
  `neutral-200`/`dark:neutral-800`, `neutral-600`/`dark:neutral-400`,
  `neutral-50`/`dark:neutral-800/50` on hover, and the focus ring.
- **Reduced motion:** the transition is removed, and script doesn't set the
  scale.

## Behaviour (JavaScript)

- **`<unmagic-dock magnify>`.** On `pointermove` over the list, it sets
  `--unmagic-dock-scale` on each action from its distance to the pointer
  (Gaussian falloff, max 1.6, over about 3 items). On `pointerleave` it resets
  them all to 1.
- **Nothing on focus;** CSS `:focus-visible` scales the item.
- **Motion:** it does nothing when
  `matchMedia("(prefers-reduced-motion: reduce)")` matches, and it listens for
  changes to that query.
- **Rendering:** it uses `requestAnimationFrame` to throttle, and removes the
  frame callback in `disconnectedCallback`.
- **Turbo:** a `turbo:before-cache` handler clears the inline scale variables,
  so a snapshot isn't frozen mid-magnify. Listeners live on the element
  (added in the constructor), so clones and moves are safe.
- **Events:** none.
- **Dependencies:** it imports `unmagic/components/tooltip`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.dock.label` | "Dock" |

## Specs

- `nav[aria-label]`, with list items holding links that have `aria-label`
  wrapped in `unmagic-tooltip[text]`.
- `aria-current` appears when `current: true`.
- The divider has `role="separator"`.
- A `--bottom` class; the `magnify` attribute is absent with `magnify: false`.
- `ArgumentError` for an unknown `position:`.

## Preview

- **Page:** `marketing`, showing an inline dock and a static
  (`magnify: false`) dock.
- **Hand-check:**
  - Magnification is smooth.
  - Tab through: focus scales each item and its tooltip shows.
  - Reduced motion disables the effect.
  - Navigate away and back: nothing is stuck enlarged.
