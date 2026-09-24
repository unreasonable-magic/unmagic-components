# `table_for` column skeletons

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `table_for(defer: true)`'s skeleton; the `skeleton`
> builder (`s.text`, `s.circle`, `s.block`, `s.button`); `avatar`, `badge`,
> `item`

This note covers one change to `table_for`: letting a column declare the shape of
its skeleton. The rest of `table_for` is documented in the README.

## Purpose

`table_for(defer: true)` renders a skeleton in a Turbo Frame, then swaps in the
real rows. Today every skeleton cell is one text bar, so the skeleton only
matches tables of plain one-line text. Real index tables don't look like that.
They have:

- **Two-line cells,** such as a name over an email, or a title over a company. The
  loaded rows are about 60px tall and the skeleton rows about 41px, so the table
  jumps when the frame swaps in.
- **Avatars:** a circle before the text.
- **Pills:** a status badge, or a row of chips.
- **Icon buttons:** a ⋮ menu in a right-aligned actions column.

With every column declared, skeleton rows should be the same height as loaded
rows, and each cell's placeholder should have the same shape as its content.

This is not a second way to describe shapes. A column's skeleton is built with
the same `Skeleton` builder that `skeleton do |s|` yields. The shapes a table
needs that the builder lacks (`badge`, `icon`, `item`) are added to the builder,
so every skeleton can use them.

## API

A column's `skeleton:` is either **one shape** or **a lambda**:

```erb
<%= table_for @candidates, defer: true do |table| %>
  <%# A lambda: the builder, with arguments or several shapes %>
  <% table.column "Name", width: "30%", skeleton: ->(s) { s.item(avatar: :medium) } do |candidate| %>
    …avatar, name, email…
  <% end %>

  <%# A symbol: that builder method, with no arguments %>
  <% table.column "Role", width: "25%", skeleton: :item do |candidate| %>
    …job title over company…
  <% end %>

  <% table.column "Status", width: "12%", skeleton: :badge do |candidate| %>
    <%= badge candidate.status %>
  <% end %>

  <% table.column "Skills", width: "25%", skeleton: ->(s) { s.badge(count: 3) } do |candidate| %>
    …chips…
  <% end %>

  <% table.column "", align: :right, width: "3rem", skeleton: :icon do |candidate| %>
    …⋮ menu…
  <% end %>
<% end %>
```

| `skeleton:` | Renders |
|---|---|
| left out | Today's single bar, with the same widths and `is-right` handling. The markup doesn't change. |
| `:text`, `:item`, `:badge`, `:icon` (any public shape) | `s.public_send(symbol)`, the builder method with no arguments |
| a lambda | `view.capture(s, &lambda)`, whatever the lambda returns |

- It has to be a lambda rather than a block because the column's block is
  already the cell's content.
- An unknown symbol raises `ArgumentError` when the column is declared, not when
  the table renders:
  `unknown skeleton shape :bogus (expected one of [:text, :circle, :block, :button, :badge, :icon, :item])`.
- **Widths still vary by row.** For `:text` and `:item`, the table passes a
  `width:` from today's scale: `SKELETON_FRACTIONS` for a column with a width,
  `SKELETON_WIDTHS` for one without. A lambda sets its own widths.
- **Details rows** (`table.details`) are left out of the skeleton on purpose. They
  are optional and per record, so any placeholder would be wrong for most rows. A
  table whose records nearly always have a details row can fold the extra height
  into the last column's lambda.

### New builder shapes

These are added to `Skeleton`, so `skeleton do |s|` and the standalone helpers
get them too:

| Method | Standalone helper | Shape |
|---|---|---|
| `badge(width: nil, count: 1, **options)` | `skeleton_badge` | A pill as tall as `badge`. `count:` gives a row of pills that doesn't wrap, just as `text(lines:)` gives a paragraph. Each pill is a little narrower than the one before, so a chip row doesn't look like one bar. |
| `icon(**options)` | `skeleton_icon` | A square the size of an icon-only button (`button_classes(:icon)`). |
| `item(avatar: nil, description: true, width: nil, **options)` | `skeleton_item` | The `item` media object: an optional avatar circle, a title line, and a shorter, smaller description line. |

- `badge`: `count:` below 1 raises `ArgumentError`, and `width:` applies to each
  pill.
- `item`:
  - `avatar:` is `:small`, `:medium` or `:large`, sized from
    `Avatar::DIMENSIONS`. Anything else raises the same `ArgumentError` as
    `avatar(size:)`.
  - `description: false` leaves just the title line.
  - `width:` sets the title line. The description line is 70% of it.
- `text(lines:)` keeps its meaning: a paragraph of same-size lines with a shorter
  last one. A title over a description is `item`, not `text(lines: 2)`.
- `class:` and other options go on the shape's outer element, as with the
  existing shapes.

## Markup

A declared column's cell carries the column's `cell_classes`, as a loaded cell
does. Inside it, the shape is wrapped in a flex row that follows the column's
alignment:

```html
<td class="is-right">
  <span class="UnmagicTableSkeleton">
    <span class="UnmagicSkeleton UnmagicSkeleton--icon" aria-hidden="true"></span>
  </span>
</td>
```

`item` builds on the existing `UnmagicSkeletonLine`, so each line is exactly one
line box of the font it sits in:

```html
<span class="UnmagicSkeletonItem" aria-hidden="true">
  <span class="UnmagicSkeleton UnmagicSkeleton--circle" style="width: 2rem; height: 2rem"></span>
  <span class="UnmagicSkeletonItem__main">
    <span class="UnmagicSkeletonLine"><span class="UnmagicSkeleton UnmagicSkeleton--text" style="width: 75%"></span></span>
    <span class="UnmagicSkeletonItem__description">
      <span class="UnmagicSkeletonLine"><span class="UnmagicSkeleton UnmagicSkeleton--text" style="width: 70%"></span></span>
    </span>
  </span>
</span>
```

`badge(count: 3)`:

```html
<span class="UnmagicSkeletonBadges" aria-hidden="true">
  <span class="UnmagicSkeleton UnmagicSkeleton--badge"></span>
  <span class="UnmagicSkeleton UnmagicSkeleton--badge" style="width: 3.5rem"></span>
  <span class="UnmagicSkeleton UnmagicSkeleton--badge" style="width: 3rem"></span>
</span>
```

A single `badge` or `icon` is one `span.UnmagicSkeleton`.

## Accessibility

- Unchanged. The skeleton table stays `role="status"`, `aria-busy="true"`, with
  the "Loading…" caption. Every shape is `aria-hidden`, so a screen reader hears
  "Loading…" once.
- Nothing is focusable.

## Styling

Put the shapes in the `Skeleton` section, after `--button`:

- **`UnmagicSkeleton--badge`:**
  - `inline-block rounded-full align-middle`, default width `w-16`.
  - Height `calc(1rem + 0.25rem)`: the `text-xs` line box plus `py-0.5`, which is
    `.UnmagicBadge`'s box.
- **`UnmagicSkeletonBadges`:** `inline-flex gap-1 overflow-hidden whitespace-nowrap`,
  the same gap as a chip row of badges.
- **`UnmagicSkeleton--icon`:**
  - `inline-block rounded-md align-middle`.
  - It's square. Each side is `.UnmagicButton--icon`'s height: `p-1.5`, the
    button's line box and a 1px border each side. Measure this in the browser and
    write it as a `calc()`, as `--button` does.
  - Under `pointer: coarse`, it matches the button's 2.75rem minimum.
- **`UnmagicSkeletonItem`:**
  - `flex w-full min-w-0 items-center gap-3` (full width, so its lines have a width to take a share of inside the table cell's flex row).
  - `__main` is `min-w-0 flex-1`.
  - `__description` is `mt-0.5 block text-xs`, matching `.UnmagicItem__description`,
    so its `1lh` line box is the smaller one.

Put `UnmagicTableSkeleton` in the Table section:

- `flex min-w-0 items-center`.
- `.is-right > &` adds `justify-end`, and `.is-center > &` adds `justify-center`.

Colours come from the existing `.UnmagicSkeleton` (`neutral-200` /
`dark:neutral-800`) and its shimmer. There are no new colours and no new
variables.

**Height check,** for the table's `text-sm` with `py-3` cells:

| Part | Height |
|---|---|
| Cell padding | 12px |
| Title line (`1lh` of `text-sm`) | 20px |
| Gap (`mt-0.5`) | 2px |
| Description line (`1lh` of `text-xs`) | 16px |
| Cell padding | 12px |
| **Row** | **62px** |

That matches the loaded rows' 60–65px. A 2rem avatar circle (32px) is shorter than
the two lines (38px), so it doesn't set the row height. Hosts whose description
style differs from `item`'s use a lambda.

## Behaviour (JavaScript)

_None._

## I18n

_None new._

## Specs

`skeleton_spec.rb`:

- **`badge`:**
  - Renders one `.UnmagicSkeleton--badge`, `aria-hidden`, taking `width:` and
    `class:`.
  - `count: 3` renders `.UnmagicSkeletonBadges` with 3 pills.
  - `count: 0` raises.
- **`icon`:** renders one `.UnmagicSkeleton--icon`, `aria-hidden`.
- **`item`:**
  - The default has no circle and 2 `.UnmagicSkeletonLine`s, the second inside
    `__description`.
  - `avatar: :small` adds a 1.5rem circle, and `:large` a 2.5rem one.
  - `description: false` gives 1 line.
  - `avatar: :huge` raises.
- **Helpers:** `skeleton_badge`, `skeleton_icon` and `skeleton_item` render the
  same markup as the builder.

`table_spec.rb`, "skeleton shapes":

- A column with no `skeleton:` renders today's markup exactly (the existing
  `SKELETON_ROWS` count spec still passes).
- `:item`, `:badge` and `:icon` render their shape in every one of the
  `SKELETON_ROWS` rows.
- A lambda receives a `Unmagic::Components::Skeleton`, and its output is the cell.
- A right-aligned column's skeleton cell has `is-right` on the `td`.
- `:item` title widths vary by row.
- `skeleton: :bogus` raises `ArgumentError` when the column is declared.

## Preview

- **Table page:**
  - Add a "Deferred, with shapes" example: an avatar + name/email column, a
    title/company column, a status badge, a chip row, and a ⋮ menu.
  - Next to it, show the same columns loaded, so the heights can be compared side
    by side.
- **Skeleton page:** add `badge`, `badge(count: 3)`, `icon` and `item` (with and
  without an avatar), each above the real component it stands in for.
- **Check by hand:**
  - Skeleton and loaded rows have the same `tr` height (`getBoundingClientRect`),
    in light and `?theme=dark`.
  - Columns don't shift when the frame swaps in.
  - The stacked phone layout.
  - `prefers-reduced-motion` stops the shimmer (inherited).

## Open questions

- `badge "…", skeleton: true`, following the "components take `skeleton: true`"
  principle, would render `s.badge`. It's cheap, but this change doesn't need it.
  Add it now or later?
- Should the table's width seed go to a lambda (for example, as a second
  argument)? The proposal says no: the lambda sets its own widths, and the rows
  look the same as each other.
