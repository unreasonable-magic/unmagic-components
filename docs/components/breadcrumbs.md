# `breadcrumbs`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Breadcrumb" (gap source); `page_header`'s
> `back:` link; `menu`

## Purpose

The trail from a section's root to the current page, for hierarchies deeper
than one level (Settings › Integrations › GitHub).

It is not for a single parent: `page_header back:` already renders one back
link, and should stay the choice when there is only one level to go up.

## API

```erb
<%= breadcrumbs do |crumbs| %>
  <% crumbs.link "Settings", settings_path %>
  <% crumbs.link "Integrations", settings_integrations_path %>
  <% crumbs.current "GitHub" %>
<% end %>

<%# Inside a page header, in place of back: %>
<%= page_header title: "GitHub" do |header| %>
  <% header.breadcrumbs do |crumbs| %>
    <% crumbs.link "Settings", settings_path %>
    <% crumbs.current "GitHub" %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | String | I18n "Breadcrumb" | The `<nav>`'s `aria-label` |

- **Parts:**
  - `crumbs.link(name, url, **options)` takes `link_to`'s arguments, block form
    included.
  - `crumbs.current(name, **options)` marks the page you are on. It is optional,
    since a trail can end on a link.
- **`current` must come last**, at most once; otherwise `render` raises
  `ArgumentError`. An empty trail renders nothing (`nil`).
- **Other options** go on the `<nav>`.
- **`page_header`** gains a `breadcrumbs` builder part that renders where
  `back:` goes. Passing both raises `ArgumentError`.

## Markup

```html
<nav class="UnmagicBreadcrumbs" aria-label="Breadcrumb">
  <ol class="UnmagicBreadcrumbs__list">
    <li class="UnmagicBreadcrumbs__item">
      <a class="UnmagicBreadcrumbs__link" href="/settings">Settings</a>
    </li>
    <li class="UnmagicBreadcrumbs__item">
      <svg class="UnmagicIcon UnmagicBreadcrumbs__separator" aria-hidden="true">…chevron_right…</svg>
      <a class="UnmagicBreadcrumbs__link" href="/settings/integrations">Integrations</a>
    </li>
    <li class="UnmagicBreadcrumbs__item">
      <svg class="UnmagicIcon UnmagicBreadcrumbs__separator" aria-hidden="true">…</svg>
      <span class="UnmagicBreadcrumbs__current" aria-current="page">GitHub</span>
    </li>
  </ol>
</nav>
```

- An ordered list inside a labelled `<nav>` is the landmark-and-list pattern
  assistive technology expects.
- The separator is rendered by the server as a hidden SVG, rather than as CSS
  `content`, so it never gets read aloud and it inherits the icon sizing.

## Accessibility

- Follows the APG
  [Breadcrumb pattern](https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/).
- `aria-label="Breadcrumb"` on the `<nav>`, and `aria-current="page"` on the
  last crumb. Separators are `aria-hidden`.
- Keyboard: ordinary links, so Tab moves through them, each with a
  `:focus-visible` ring.

## Styling

CSS section: `Breadcrumbs`.

- **Elements:** `UnmagicBreadcrumbs`, `__list`, `__item`, `__separator`,
  `__link` and `__current`.
- **List:**
  - `display: flex`, `flex-wrap: wrap`, `gap: 0.375rem`.
  - The list-style, margin and padding are reset, since hosts often style bare
    `ol` and `nav a`.
- **Type and colour:**
  - 0.875rem.
  - Links are `neutral-500`, turning `neutral-900`/`dark:neutral-100` on hover, with no
    underline.
  - The current crumb is `neutral-900`/`dark:neutral-100` at weight 500.
  - The separator is `neutral-500` at 0.875rem.
- **Long trails:** each `__link` gets `max-width: 16rem`, an ellipsis, and a
  `title` with the full name.
- **Inside `page_header`:** the crumbs take the same margin as
  `UnmagicPageHeader__back`.
- Palette colours with `dark:` variants only, and no motion.

## Small screens

Below `sm` only the last two crumbs show, with an ellipsis before them: the
page before this one and this one. The rest of the trail is what a phone's
back button is for.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.breadcrumbs.label` | "Breadcrumb" |

## Specs

- **Structure:**
  - `nav.UnmagicBreadcrumbs[aria-label=Breadcrumb] > ol > li` count matches the
    crumbs.
  - Links carry `href` and text.
  - The last crumb is `span[aria-current=page]`.
- **Separators:** the first `li` has no `.UnmagicBreadcrumbs__separator`, and
  every later one has exactly one, `aria-hidden`.
- **Blocks and options:** `crumbs.link` with a block captures its content, and
  `class:` / `data:` reach the `<a>`.
- **`current` first or twice** raises `ArgumentError`. An empty block returns
  `nil`.
- **`label:`** overrides the `aria-label`.
- **`page_header`:**
  - the `breadcrumbs` part renders `.UnmagicBreadcrumbs` inside the header
  - there is no `.UnmagicPageHeader__back`
  - combining it with `back:` raises

## Preview

`primitives` page, `breadcrumbs` section:
- a three-level trail
- a trail with one very long name, showing the truncation
- a `page_header` using `header.breadcrumbs`

**Check by hand:** wrapping at a narrow width, the focus ring, and the dark
theme.

## Open questions

- **Collapsing long trails into a `menu`** ("Settings › … › GitHub") would need
  no new JS. Worth it only if an app has trails deeper than four levels.
- **The glyph** is a new `chevron_right` in `Icons::PATHS`, from Lucide
  `chevron-right`. It is shared with `tree_view`.
