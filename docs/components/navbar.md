# `navbar`

> Status: draft
> Tier: 2 (small element for the mobile disclosure)
> Replaces or relates to: Rails Blocks "Navbar" (gap source). Designed alongside `sidebar` (sidebar.md), and reuses `menu` for account dropdowns and `tabs`' `aria-current` link styling.

## Purpose

The horizontal bar across the top of an application:
- a brand at the start
- primary links in the middle
- actions at the end (search, a notifications button, an account `menu`)

Below a breakpoint the links collapse behind a menu button.

Use `sidebar` instead when the app has more than about six sections or needs
nested groups. The two share link and current-page semantics so an app can
switch between them, and a sidebar layout can still use `navbar` as its thin
top bar.

**Placement:** core CSS. It is application chrome.

## API

```erb
<%= navbar label: "Main" do |nav| %>
  <% nav.brand root_path do %><%= image_tag "logo.svg", alt: "Acme" %><% end %>
  <% nav.link "Jobs", jobs_path, current: current_page?(jobs_path) %>
  <% nav.link "Candidates", candidates_path, current: controller_name == "candidates" %>
  <% nav.actions do %>
    <%= menu "Ada" do |menu| %>…<% end %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | "Main" (I18n) | `aria-label` on the `<nav>` |
| `sticky:` | boolean | `false` | `position: sticky; top: 0` |
| `collapse:` | `:sm`, `:md`, `:lg`, `false` | `:md` | Width below which links collapse; validated |

- `brand(url = nil, &block)` renders the brand, as a link when `url` is given.
- `link(name, url, current: false, **options)` takes link_to's arguments and
  block form.
- `actions(&block)` holds the actions at the end.
- Other options go on the `<header>`.

## Markup

```html
<header class="UnmagicNavbar UnmagicNavbar--collapse-md">
  <unmagic-navbar class="UnmagicNavbar__inner">
    <a class="UnmagicNavbar__brand" href="/">…</a>
    <details class="UnmagicNavbar__disclosure">
      <summary class="UnmagicButton UnmagicButton--icon UnmagicNavbar__toggle" aria-label="Menu">…menu icon…</summary>
    </details>
    <nav class="UnmagicNavbar__nav" aria-label="Main">
      <ul class="UnmagicNavbar__links">
        <li><a class="UnmagicNavbar__link" href="/jobs" aria-current="page">Jobs</a></li>
      </ul>
    </nav>
    <div class="UnmagicNavbar__actions">…</div>
  </unmagic-navbar>
</header>
```

- **Above the breakpoint** the disclosure is `display: none` and the nav always
  shows.
- **Below it** the nav shows only while the disclosure is open, via
  `.UnmagicNavbar__inner:has(> .UnmagicNavbar__disclosure[open]) .UnmagicNavbar__nav`.
  That works with no script. The `<details>` holds only the toggle, so the
  `<nav>` keeps its landmark in the page flow.

## Accessibility

- A `<header>` (banner landmark when top-level) containing a labelled `<nav>`.
- `aria-current="page"` marks the current link. Colour and a 2px underline both
  show it.
- The toggle is a `summary` with `aria-label` "Menu". Script mirrors its state
  to `aria-expanded` and `aria-controls` on the summary.
- Keyboard: normal Tab order through the links (it is navigation, not a menu
  widget). Escape closes the mobile panel and returns focus to the toggle.

## Styling

- **Section:** `Navbar`.
- **Elements:** `__inner`, `__brand`, `__disclosure`, `__toggle`, `__nav`,
  `__links`, `__link`, `__actions`.
- **Modifiers:** `--sticky`, `--collapse-sm|md|lg` (40rem/48rem/64rem media
  queries).
- **Links** reuse the `Tabs` link look: `text-3` becoming `text` on hover and
  when `[aria-current="page"]`. Reset `margin` and `text-decoration`, as `Tabs`
  does, against host `nav a` rules.
- **Tokens:** `surface`, `border` (bottom border), `text`, `text-3`, `hover`,
  `focus`, `accent` (current underline).
- **Mobile panel:** a full-width column below the bar, with a 150ms fade that
  is removed under reduced motion.

## Behaviour (JavaScript)

**`<unmagic-navbar>`** adds only what `<details>` lacks, following `menu.js`:
- It closes on Escape, on choosing a link, on an outside press, and when the
  viewport grows past the breakpoint (`matchMedia` change).
- It keeps `aria-expanded` in sync on the summary.
- On `turbo:before-cache` it closes, so a restored snapshot isn't open.
- Document listeners are added on open and removed on close and disconnect.
- It fires no events.
- It needs no Turbo, and no sibling imports beyond whatever `menu` the caller
  uses.

Shared with sidebar.md: both could share one "close on navigation" helper.
Coordinate this with the sidebar note before building.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.navbar.label` | "Main" |
| `unmagic.components.navbar.toggle` | "Menu" |

## Specs

- `header > unmagic-navbar`, with `nav[aria-label]` containing links.
- `aria-current="page"` appears only on `current: true`.
- The brand is a link with `url`, and a span without.
- Actions render, and are omitted when not given.
- `--sticky` and `--collapse-*` classes appear.
- `collapse: false` renders no disclosure.
- `ArgumentError` for `collapse: :xl`.
- `class:` passes through to the header.

## Preview

- **Page:** `primitives`, in a framed demo area (not the preview's own header).
  Show one bar with an account `menu`, and one with `sticky:` inside a
  scrolling box.
- **Hand-check:**
  - Resize past the breakpoint.
  - Open the panel and press Escape: focus returns to the toggle.
  - Turbo back/forward doesn't leave it open.
  - Dark mode.

## Open questions

- Should the brand and actions stay visible in the collapsed panel, or move
  into it?
