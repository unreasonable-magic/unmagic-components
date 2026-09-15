# `tree_view`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Tree View" (gap source); `disclosure`
> (the same `<details>` toggle); `breadcrumbs`

## Purpose

A nested, collapsible list of things that live inside other things:
- a repository's files
- an organisation's teams
- a documentation sidebar
- a JSON payload's keys

Leaves are usually links to a page, and branches fold.

It is not the APG `tree` widget, a single tab stop with arrow-key navigation.
That needs script and is noted as a Tier 2 upgrade. Here it is nested lists of
links and disclosures, which work everywhere with Tab alone.

## API

```erb
<%= tree_view label: "Files" do |tree| %>
  <% tree.branch "app", icon: :folder do |app| %>
    <% app.branch "models", icon: :folder do |models| %>
      <% models.leaf "user.rb", href: blob_path("app/models/user.rb"), icon: :file, current: true %>
      <% models.leaf "team.rb", href: blob_path("app/models/team.rb"), icon: :file %>
    <% end %>
  <% end %>
  <% tree.leaf "Gemfile", href: blob_path("Gemfile"), icon: :file %>
<% end %>

<%# A leaf with markup %>
<% tree.leaf href: team_path(team) do %><%= team.name %> <%= badge team.size %><% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | String | — | Required; the `aria-label` of the root list |
| `guides:` | Boolean | `true` | Vertical guide lines per level |

**Branch and leaf options:**

| Option | Values | Default | Notes |
|---|---|---|---|
| `open:` (branch) | Boolean | auto | Default: open when a descendant is `current:` |
| `href:` (leaf) | URL | `nil` | Without it the leaf is plain text |
| `current:` (leaf) | Boolean | `false` | `aria-current="page"`; opens its ancestors |
| `icon:` | `Icons::PATHS` name or `nil` | `nil` | Unknown names raise, via `Icons.svg` |

- **Nesting:** `branch` yields a builder of the same class, so levels nest to
  any depth. The recursion happens in `render`, once the whole tree is
  collected, which is what lets `open:` default from descendants.
- **Empty branches** render with an empty-state line in the panel: "Empty",
  through I18n.
- **Other options** go on the root `<ul>`.

## Markup

```html
<ul class="UnmagicTree UnmagicTree--guides" aria-label="Files">
  <li class="UnmagicTree__node">
    <details class="UnmagicTree__branch" open>
      <summary class="UnmagicTree__row">
        <svg class="UnmagicIcon UnmagicTree__toggle" aria-hidden="true">…chevron_right…</svg>
        <svg class="UnmagicIcon UnmagicTree__icon" aria-hidden="true">…folder…</svg>
        <span class="UnmagicTree__label">app</span>
      </summary>
      <ul class="UnmagicTree__children">
        <li class="UnmagicTree__node">
          <a class="UnmagicTree__row UnmagicTree__row--leaf" href="/blob/app/models/user.rb" aria-current="page">
            <svg class="UnmagicIcon UnmagicTree__icon" aria-hidden="true">…file…</svg>
            <span class="UnmagicTree__label">user.rb</span>
          </a>
        </li>
      </ul>
    </details>
  </li>
</ul>
```

- **Leaf alignment:** a leaf row reserves the toggle's width with padding, so
  labels line up under their branch.
- **Native toggling:** `<details>` gives opening and closing with no JS, as in
  `disclosure`.

## Accessibility

- **Structure:** nested `<ul>` elements convey level and position ("list, 3
  items, level 2"). There is no `role="tree"`: that role promises arrow-key
  behaviour this tier doesn't provide.
- **Branches:** each is a `<summary>`, exposed as an expandable button.
  Enter or Space toggles.
- **Leaves:** links with `aria-current="page"` for the current item. Tab moves
  through visible rows in order.
- **Labels:** the root list is labelled by `label:`, and icons and toggles are
  `aria-hidden`.

## Styling

CSS section: `Trees`.

- **Elements:** `UnmagicTree` (with `--guides`), `__node`, `__branch`, `__row`
  (with `--leaf`), `__toggle`, `__icon`, `__label` and `__children`.
- **Resets:** list-style, margin and padding on `ul`, and the summary markers,
  as in `UnmagicMenu__trigger`.
- **Row:**
  - `flex`, `gap: 0.375rem`, `padding: 0.25rem 0.5rem`, radius 0.375rem,
    0.875rem type in `neutral-600`/`dark:neutral-400`, no underline.
  - Hover: `neutral-50`/`dark:neutral-800/50`.
  - `[aria-current=page]`: `neutral-100`/`dark:neutral-800` with `neutral-900`/`dark:neutral-100` at
    weight 500.
  - A `:focus-visible` ring.
- **Toggle:** `[open] > summary .UnmagicTree__toggle` rotates 90°.
- **Icons:** `neutral-500`.
- **Children:** `margin-left: 0.75rem` and `padding-left: 0.5rem`. With
  `--guides`, a 1px `neutral-200`/`dark:neutral-800` left border.
- **Labels:** truncate with an ellipsis. `title` carries the full text for
  string labels.
- **Reduced motion:** the toggle's rotation transition is off.
- Palette colours with `dark:` variants only.

## Behaviour (JavaScript)

_None. CSS and markup only._

A morph refresh resets branches to the server's `open` state. Because
branches containing the current leaf default to open, the useful path stays
visible.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.tree.empty` | "Empty" |

## Specs

- **Root:** `ul.UnmagicTree[aria-label=Files]`. Branches are
  `li > details.UnmagicTree__branch > summary.UnmagicTree__row`, with children
  in `ul.UnmagicTree__children`.
- **Nesting:** three levels deep, and the node count matches.
- **Current leaf:** `current: true` renders `a[aria-current=page]`, and every
  ancestor `details` has `open`. A sibling branch without a current leaf
  doesn't.
- **Explicit `open:`:** `open: false` on an ancestor of the current leaf wins.
- **Leaf content:** no `href:` → `span.UnmagicTree__row--leaf`. The block form
  captures markup.
- **Options:** `guides: false` omits `UnmagicTree--guides`.
  `icon: :nonexistent` raises `ArgumentError`. A missing `label:` raises.
- **Empty branch:** renders the "Empty" line.

## Preview

`primitives` page, `tree_view` section:
- a file tree three levels deep with the current file
- a teams tree with badges in leaf labels
- `guides: false`

**Check by hand:**
- Keyboard Tab order through open branches only.
- Truncation at a narrow width.
- The dark theme.
- The current path is open on load.

## Open questions

- **An APG-conformant tree.** Upgrading to a single tab stop with arrow-key
  navigation and typeahead would need an `<unmagic-tree>` element (Tier 2). It
  is worth it for large trees; proposal: defer.
- **New glyphs:** `folder` and `file` (Lucide), plus the `chevron_right` shared
  with `breadcrumbs`. Should `icon:` also accept a captured block for
  host-provided icons?
