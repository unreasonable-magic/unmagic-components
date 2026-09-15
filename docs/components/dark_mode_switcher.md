# `theme_switcher`

> Status: draft
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Dark Mode Switcher" (gap source). Visually a segmented control like `tabs`.

## Purpose

Lets a user choose Light, Dark or System. The gem still ships **no dark theme**
and makes **no assumption about how the host selects one**:

- The switcher only writes the choice to an attribute (or class) the host
  names, on an element the host names, and remembers it.
- The host's own tokens do the flipping, as the stylesheet header describes.

**Placement:** core CSS. It is application settings chrome.

## API

```erb
<%# The layout: the server applies the saved choice, so there's no flash %>
<html lang="en" <%= theme_attributes %>>

<%# Anywhere: the control %>
<%= theme_switcher %>
<%= theme_switcher attribute: "class", values: { light: "", dark: "dark" }, style: :toggle %>
```

`theme_switcher(**options)`:

| Option | Values | Default | Notes |
|---|---|---|---|
| `attribute:` | string | `"data-theme"` | Or `"class"` |
| `values:` | `{ light:, dark: }` | `{ light: "light", dark: "dark" }` | Written to the attribute; `system` resolves via `prefers-color-scheme` |
| `target:` | CSS selector | `"html"` | The element that carries the attribute |
| `style:` | `:segmented`, `:toggle` | `:segmented` | `:toggle` is a single light/dark icon button with no "system" |
| `cookie:` | string or `false` | `"unmagic_theme"` | Also persisted to `localStorage` |

`theme_attributes(attribute: "data-theme", values: …, cookie: "unmagic_theme")`
returns the attribute hash for the `<html>` tag, read from the cookie:

- A saved light or dark choice renders the attribute.
- `system`, or no cookie, renders nothing, and a one-line inline script applies
  `prefers-color-scheme` before first paint. See the open questions.

The same `attribute:`, `values:` and `cookie:` options must be passed to both,
or set once as `config.theme`. See the proposed principle changes.

## Markup

```html
<unmagic-theme-switcher class="UnmagicThemeSwitcher" attribute="data-theme" target="html"
  values='{"light":"light","dark":"dark"}' cookie="unmagic_theme">
  <div class="UnmagicThemeSwitcher__list" role="radiogroup" aria-label="Theme">
    <button type="button" role="radio" aria-checked="false" value="light" class="UnmagicThemeSwitcher__option" tabindex="-1">…sun…<span class="UnmagicVisuallyHidden">Light</span></button>
    <button type="button" role="radio" aria-checked="false" value="dark"  class="UnmagicThemeSwitcher__option" tabindex="-1">…moon…<span class="UnmagicVisuallyHidden">Dark</span></button>
    <button type="button" role="radio" aria-checked="true"  value="system" class="UnmagicThemeSwitcher__option" tabindex="0">…monitor…<span class="UnmagicVisuallyHidden">System</span></button>
  </div>
</unmagic-theme-switcher>
```

- **The server renders `aria-checked`** from the cookie.
- **Without script** the buttons do nothing; the server-rendered theme still
  applies. It could degrade to a form posting the cookie, but that's out of
  scope, since the switch is inherently client-side.

## Accessibility

- A labelled `radiogroup` of `radio` buttons, following the APG radio group
  pattern: roving `tabindex`, arrow keys move and select, Home and End jump.
- Icon options carry visually hidden names, and matching `title`s.
- `:toggle` style is a single `button` with `aria-pressed` (dark = true) and an
  `aria-label` of "Dark mode".

## Styling

- **Section:** `Theme switcher`.
- **Elements:** `__list`, `__option`.
- **Look:** the segmented look reuses the `Tabs` track tokens (`surface-3`
  track, `raised` for `[aria-checked="true"]`).
- **Icons:** add `sun`, `moon` and `monitor` Lucide paths to `Icons::PATHS`.
- **Focus** uses `focus`.
- **Motion:** none, and the colour change itself isn't animated. The note
  recommends that hosts don't transition every colour.

## Behaviour (JavaScript)

**`<unmagic-theme-switcher>`** reads `attribute`, `values` (JSON), `target` and
`cookie`. On choosing:

1. It writes `localStorage["unmagic-theme"]` and a one-year `SameSite=Lax`
   cookie, so the next server render is right.
2. It resolves `system` through `matchMedia("(prefers-color-scheme: dark)")`.
3. It sets the attribute on `document.querySelector(target)`. For
   `attribute="class"` it removes the other value's class and adds this one.
4. It updates `aria-checked` and `tabindex` on every switcher on the page, so
   several stay in sync.
5. It fires `unmagic-theme:change` with `{ choice, resolved }` on `document`.

It also:

- **Follows the OS while in `system`,** listening to the media query's
  `change`.
- **Keeps a shared module state** for document-level listeners (the media
  query, `storage` events from other tabs), guarded with a `Symbol.for` flag as
  `dialog.js` is. Each element only renders the state.
- **Handles Turbo:**
  - Drive replaces `<body>`, not `<html>`, so the attribute survives visits.
  - On `turbo:morph` and `turbo:render` it re-applies the saved choice, in case
    a morph rewrote `<html>` attributes to the server's.
  - `connectedCallback` syncs `aria-checked` from storage, so a cached snapshot
    is correct.
- **Needs no Turbo.**

**How the preview layout would use it.** Today
`preview/views/layouts/preview.html.erb` uses `?theme=dark` links and
`data-theme` on `<html>`. It would switch to
`<html lang="en" <%= theme_attributes %>>` and `<%= theme_switcher %>` in the
header nav, and the `[data-theme="dark"]` token block stays exactly as it is.
It is the host-style example of pointing the switcher at attributes the host
already styles. Keep `?theme=` as an override for screenshot links.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.theme.label` | "Theme" |
| `unmagic.components.theme.light` / `.dark` / `.system` | "Light" / "Dark" / "System" |
| `unmagic.components.theme.toggle` | "Dark mode" |

## Specs

- A `radiogroup` with 3 radios; `aria-checked` follows the cookie (`build_view`
  with a cookie header).
- Attributes are serialised onto the element (`values` as JSON).
- `theme_attributes` returns `{ "data-theme" => "dark" }` for a dark cookie,
  `{ class: "dark" }` in class mode, and `{}` for system or no cookie.
- `:toggle` renders one `aria-pressed` button.
- `ArgumentError` for an unknown `style:` or a `values:` missing `:light` or
  `:dark`.

## Preview

- **Page:** the layout header, as described above.
- **Hand-check:**
  - Choose Dark and reload: no flash of light.
  - With System, change the OS appearance: it follows.
  - A second tab syncs.
  - Arrow keys in the radiogroup.
  - A Turbo visit keeps the theme.

## Open questions

- Is the tiny inline `<script>` for `system` acceptable in the gem? It needs a
  CSP nonce (`theme_script_tag nonce: true`). The alternative is setting both
  values from CSS `@media (prefers-color-scheme)`, which is the host's job.
- Should `config.theme` exist, so `theme_attributes` and `theme_switcher` can't
  disagree?
