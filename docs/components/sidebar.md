# `sidebar` / `sidebar_toggle`

> Status: draft
> Tier: 2 (small element)
> Replaces or relates to:
> - Rails Blocks "Sidebar" (the gap source; its "Navbar" is out of scope)
> - `tabs` (link bar marking `aria-current`), `menu`, `badge`

## Purpose

An application's main navigation, set down the side of the layout: sections of
links, with the current page marked. On narrow screens it folds away behind a
toggle and opens as a sheet over the page.

It is **not** for switching views within a page (use `tabs`) or for actions
(use `menu`). It renders the navigation itself, not the page grid: the layout
still decides where the sidebar sits.

## API

```erb
<%= sidebar label: "Main", collapse_below: :lg, id: "app_nav" do |nav| %>
  <% nav.header { link_to image_tag("logo.svg", alt: "Acme"), root_path } %>
  <% nav.section do |s| %>
    <% s.link "Inbox", inbox_path, icon: inline_svg("inbox"), badge: @unread %>
    <% s.link "Issues", issues_path, active: controller_name == "issues" %>
  <% end %>
  <% nav.section "Settings", collapsible: true do |s| %>
    <% s.link "Members", members_path %>
  <% end %>
  <% nav.footer { render "account_menu" } %>
<% end %>

<%# In the top bar, visible only below the breakpoint %>
<%= sidebar_toggle "app_nav" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | "Main" (I18n) | The `<nav>`'s `aria-label` |
| `id:` | string | required | The toggle targets it |
| `collapse_below:` | `:md`, `:lg`, `:never` | `:lg` | Validated. `:md` is 48rem, `:lg` is 64rem |
| `section` `collapsible:` | boolean | `false` | Uses `<details>`. Open when it holds the current page, or with `open: true` |
| `link` `active:` | boolean or nil | nil | nil falls back to `current_page?(url)` |
| `link` `icon:`, `badge:` | markup, or text/number | nil | A badge renders `badge(tone: :neutral)`; blank or 0 renders nothing |

- A section's title is optional. Other `link` options go to `link_to`, and other
  options go on the `<nav>`.
- There is no built-in "collapse to icons" mode in v1.

## Markup

```html
<unmagic-sidebar class="UnmagicSidebar UnmagicSidebar--below-lg">
  <nav id="app_nav" class="UnmagicSidebar__panel" aria-label="Main" popover>
    <div class="UnmagicSidebar__header">…</div>
    <div class="UnmagicSidebar__section">
      <ul class="UnmagicSidebar__list" role="list">
        <li><a class="UnmagicSidebar__link" href="/inbox" aria-current="page">
          <span class="UnmagicSidebar__icon">…</span>
          <span class="UnmagicSidebar__text">Inbox</span>
          <span class="UnmagicBadge">3</span>
        </a></li>
      </ul>
    </div>
    <details class="UnmagicSidebar__section" open>
      <summary class="UnmagicSidebar__title">Settings</summary>
      <ul class="UnmagicSidebar__list" role="list">…</ul>
    </details>
    <div class="UnmagicSidebar__footer">…</div>
  </nav>
</unmagic-sidebar>

<button type="button" class="UnmagicButton UnmagicButton--icon UnmagicSidebarToggle"
        popovertarget="app_nav" aria-label="Menu" title="Menu"><svg …></svg></button>
```

A non-collapsible section with a title uses
`<h2 class="UnmagicSidebar__title" id="…">` and `aria-labelledby` on its list.

**Native pieces.** The same `<nav>` works at both widths, so the links are
never rendered twice:
- `popover` turns it into a sheet: hidden until the toggle opens it, closed on
  a light dismiss or Escape, and drawn in the top layer.
- Above the breakpoint, author CSS overrides the UA's
  `[popover]:not(:popover-open)` rule and lays the nav out inline.
- `<details>` gives collapsible sections.

Without JavaScript the whole thing still works: popovers and details are HTML.

## Accessibility

- **Pattern:** the landmark `<nav aria-label>` with lists of links, which is
  not an ARIA menu. The current page carries `aria-current="page"`.
- **Keyboard:**

| Key | Where | Does |
|---|---|---|
| Tab / Shift+Tab | anywhere | Moves through links and summaries in order |
| Enter / Space | summary | Toggles a collapsible section |
| Escape | open sheet | Closes it (native popover); focus returns to the toggle |

- **Toggle state:** the toggle's expanded state is exposed by the browser via
  `popovertarget`.
- **Focus:**
  - On opening, script moves focus to the current link, or else the first link.
  - The sheet is non-modal, so focus isn't trapped.
  - Light dismiss closes it when focus leaves.
- **Labels and icons:** the toggle label comes from I18n. Icons are
  `aria-hidden`, and a badge's count is read as part of the link name.

## Styling

- **CSS section `Sidebar`.**
  - Elements: `__panel`, `__header`, `__section`, `__title`, `__list`,
    `__link`, `__icon`, `__text`, `__footer`.
  - Modifiers: `UnmagicSidebar--below-md`, `--below-lg`, `--never`.
  - `UnmagicSidebarToggle` is hidden above the breakpoint.
- **State:**
  - `[aria-current="page"]` gives `--unmagic-surface-3` and `--unmagic-text`.
  - Hover uses `--unmagic-hover`.
  - `details[open]` rotates the chevron.
  - `:popover-open` slides the sheet in from the inline start.
- **Below the breakpoint the sheet is:**
  - `position: fixed; inset: 0 auto 0 0; width: min(18rem, 85vw)`
  - on `--unmagic-surface`, with a shadow
  - backdrop `::backdrop { background: var(--unmagic-backdrop) }`
- **Above it:** `display: flex; position: static` and `inset: auto`, filling
  the column the layout gives it.
- **Motion:** a 150ms transform on open, removed under reduced motion.
- **No new tokens.**

## Behaviour (JavaScript)

`<unmagic-sidebar>` is small, because the native elements do the work.

What it adds:
- When the sheet opens (`toggle` event, `newState === "open"`), focus moves to
  the current or first link.
- The sheet closes when a link inside it is followed. Turbo Drive keeps the
  page alive, so without this the sheet would stay open over the next page.
- It fires `unmagic-sidebar:toggle` with `{ open }`.

Turbo:
- **Cache:** it hides the popover on `turbo:before-cache`. Open state isn't an
  attribute, so the snapshot is closed anyway; this also clears the top layer.
- **Morph:** the server re-renders `aria-current` for the new page, and
  Idiomorph patches it. `<details open>` follows the server's markup, so a
  section the reader collapsed reopens after a morph. That is acceptable for v1
  (see the open questions).
- **Snapshot clones:** there is no generated DOM, so nothing to clean.
- **Streamed content:** a streamed badge count (`turbo_stream.replace` of a
  link) needs no setup, because behaviour hangs off element listeners and the
  native popover.
- **Permanent:** don't mark the sidebar `data-turbo-permanent`, or
  `aria-current` would go stale. The README warns about this.

Dependencies: none, and it doesn't need Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.sidebar.label` | "Main" |
| `unmagic.components.sidebar.toggle` | "Menu" |

## Specs

- Renders `nav[popover][aria-label]` with an id, sections, and lists of links.
- `aria-current="page"`:
  - comes from `active: true`
  - comes from `current_page?` (`build_view(path: "/inbox")`)
  - is absent when `active: false`
- `collapsible: true` renders `details > summary`. It is `open` when it holds
  the current link or has `open: true`.
- `badge:` renders an `UnmagicBadge`; blank or 0 renders none.
- `sidebar_toggle` renders `button[popovertarget=app_nav][aria-label]`.
- `class:` and attributes pass through.
- An unknown `collapse_below:` raises `ArgumentError`, and so does a missing
  `id:`.

## Preview

A new `/sidebar` page that renders a full app shell (sidebar, top bar, content)
in a resizable frame.

Hand checks:
- Narrow the window: the toggle appears and the sheet opens and closes. Escape
  and a click outside close it, and focus returns to the toggle.
- A followed link closes the sheet.
- Back restores the page closed.
- Keyboard walk-through, dark mode, and reduced motion with no slide.

## Open questions

- **Collapsed state:** should a collapsed section be remembered across pages
  (`sessionStorage`, keyed by the id, like `tabs`)?
- **Icon rail:** is a "rail" mode, collapsed to icons on desktop, wanted? It
  needs tooltips on the links and a stored preference.
- **Toggle placement:** should `sidebar_toggle` sit inside the nav's header
  instead, which would take a second close button?
