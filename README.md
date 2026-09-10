# Unmagic::Components

Declarative table and detail-list builders for server-rendered Rails views, in
the spirit of `form_for`: describe the columns, get the chrome.

```erb
<%= table_for @users do |table| %>
  <% table.empty "No team members yet." %>

  <% table.column "Name", width: "38%" do |user| %>
    <%= link_to user.name, user %>
  <% end %>

  <% table.column "Created", sort: :created_at, direction: :desc do |user| %>
    <%= user.created_at.to_fs(:short) %>
  <% end %>

  <% table.column "Logins", :sign_in_count, numeric: true %>
<% end %>
```

## Features

- **Sortable headers** that toggle `?sort`/`?direction`, carry `aria-sort`, and
  preserve the rest of the query string.
- **Deferred tables** — `defer: true` renders a skeleton inside a Turbo Frame
  without touching the collection, then loads the real rows into it. The
  skeleton keeps the loaded table's headers and column widths, so nothing shifts
  when the data lands.
- **Two flavours of empty state**: a blank slate for an empty dataset, and a
  separate one for a search that matched nothing, chosen automatically.
- **Companion detail rows** under any record, skipped per row when empty.
- **Detail lists** in inline and stacked layouts, with blanks rendered as an em
  dash so call sites don't each need `.presence || "—"`.
- **No hard dependency** on a pagination library or on any helper of yours.

## Installation

```ruby
gem "unmagic-components"
```

Add the stylesheet to your layout:

```erb
<%= stylesheet_link_tag "unmagic/components" %>
```

The engine mixes the helpers into ActionView automatically — no initializer
needed to get started.

## Theming

The stylesheet is plain CSS driven by custom properties, and every value falls
back to a Tailwind palette default, so the components look right unconfigured.
To match your own design, set the `--unmagic-*` knobs wherever your theme lives:

```css
:root {
  --unmagic-surface:       var(--surface);
  --unmagic-surface-2:     var(--surface-2);
  --unmagic-hover:         var(--hover);
  --unmagic-border:        var(--border);
  --unmagic-border-strong: var(--border-strong);
  --unmagic-text:          var(--text);
  --unmagic-text-2:        var(--text-2);
  --unmagic-text-3:        var(--text-3);
  --unmagic-skeleton:      var(--surface-3);
}
```

Dark mode needs nothing extra. If your own tokens already flip, these flip with
them — the gem ships no dark variant and makes no assumption about how you
select a theme.

The CSS is deliberately **not** part of any Tailwind build. Tailwind only
generates classes it can see and it does not scan installed gems, so a component
library that emitted utilities from Ruby would render unstyled in your app
unless you pointed `@source` at the gem's install path.

If you do want Tailwind utilities from these tokens, map them with `@theme
inline` — not plain `@theme`. A non-inline theme variable makes the utility emit
`var(--color-unmagic-surface)`, which resolves *where that variable is defined*,
so an override scoped to a subtree (a themed preview pane, a `.dark` region)
would be invisible to it:

```css
@theme inline {
  --color-unmagic-surface: var(--unmagic-surface);
}
```

## Configuration

Three seams, each with a working default. Point them at your own versions if you
already own these concerns:

```ruby
# config/initializers/unmagic_components.rb
Unmagic::Components.configure do |config|
  # The table's blank slate. Called with (view, content, **options), where the
  # options are whatever `table.empty` was given beyond its text.
  config.empty_state = ->(view, content, **options) { view.empty_state(content) }

  # The table's pager. Called with (view, pagy:, turbo_frame:).
  config.pagination = ->(view, pagy:, turbo_frame:) {
    view.render "shared/pagination", pagy: pagy, turbo_frame: turbo_frame
  }

  # Resolves the pager object a table pages with. Called with (view, collection);
  # return nil to suppress the pager. Nothing here is Pagy-specific — the
  # renderer only needs something answering previous/next/page_url, so
  # geared_pagination or your own object works just as well.
  config.pagy_for = ->(view, collection) { view.table_pagy(collection) }
end
```

## Usage

### `table_for(collection, **options, &block)`

| Option | Default | Meaning |
|---|---|---|
| `defer:` | `false` | Render a skeleton in a Turbo Frame first, then load the rows |
| `id:` | `"#{controller_name}_table"` | The frame id, when deferring |
| `paginate:` | `true` | `false` suppresses the pager; a pagy object is used directly |
| `headers:` | `true` | `false` omits the `<thead>` |
| `sorted_by:` | `params[:sort]` | The currently applied sort key |
| `sort_direction:` | `params[:direction]` | `:asc` or `:desc` |
| `sort_url:` | — | `->(key, direction) { url }`, when sorting rides on other params |
| `row_class:` | — | `->(record) { "…" }` for extra `<tr>` classes |

Any other option rides on the `<table>` itself — `class:`, `data:`, `aria-*` — so a
view can space or annotate the table without wrapping it in a div. `id:` is the
exception: it names the deferred turbo frame, not the table.

On the yielded builder:

- `column(title = nil, attribute = nil, **options, &block)` — content comes from
  the block, else `record.public_send(attribute)`. Options: `sort:`,
  `direction:`, `align:` (`:right`/`:center`), `numeric:` (right-aligns and uses
  tabular figures), `width:`, `class:`.
- `details(&block)` — a full-width companion row per record; capturing nothing
  skips it.
- `empty(text = nil, **options, &block)` — the blank slate for an empty dataset.
- `no_results(text = nil, **options, &block)` — shown instead when the collection
  responds to `filtered?` with true.

Extra options on `empty`/`no_results` are handed to the configured `empty_state`
seam, so an app whose blank slate takes more than a message can ask for it per
table:

```erb
<% table.empty "No labels yet.", icon: "tag" %>
```

```ruby
config.empty_state = ->(view, content, **options) do
  view.render "shared/empty", icon: options.fetch(:icon, "table"), message: content
end
```

`width:` takes a CSS length (`"40%"`, `"170px"`), which rides on a `<col>` as a
style, or any other string, which is used as a class name so a Tailwind app can
pass `"w-[40%]"`. Any width switches the table to a fixed layout. Give every
column of a deferred table a width, so the skeleton and the rows that replace it
lay out identically.

### `detail_list(variant: :inline, **options, &block)`

```erb
<%= detail_list variant: :stacked do |list| %>
  <% list.item "Client ID", @application.uid, class: "font-mono" %>
  <% list.item "Redirect URIs", span: :full do %>
    <% @application.redirect_uris.each do |uri| %>
      <div><%= uri %></div>
    <% end %>
  <% end %>
  <% list.item "Registered", @application.created_at %>
<% end %>
```

`:inline` lays labels beside values in a two-column grid; `:stacked` puts small
caps labels above values, in two columns once there is room. An item's `class:`
lands on its `<dd>`, and `span: :full` stretches a stacked item across both
columns.

### `table_tag(headers, rows, **options)`

The primitive the table is built on, for a static table that wants the same look
without the record/sort/pagination machinery:

```erb
<%= table_tag [ "Name", "Score" ], [ [ "Ann", 42 ], [ "Bob", 7 ] ], aligns: [ nil, :right ] %>
```

A cell is a value, or a `{ content:, **attrs }` hash setting attributes on its
`th`/`td`. A row is an array of cells, or a `{ cells:, **attrs }` hash setting
attributes on its `<tr>`. `aligns:` and `widths:` are per-column, and `caption:`
adds a screen-reader-only caption.

## Forms

`FormBuilder` is the chrome around a control — the wrapper, the label and its
required marker, the hint, and the error line — the part every app writes the same
way and then repeats in every view.

```erb
<%= form_with model: @label, builder: Unmagic::Components::FormBuilder do |form| %>
  <%= form.errors_summary %>
  <%= form.field :name, "Name", required: true, hint: "A key is derived from it." %>
  <%= form.field :colour, "Colour" do %>
    <%= form.select :colour, Label::COLOURS %>
  <% end %>
  <%= form.submit "Add label" %>
<% end %>
```

Set it as the default with `config.action_view.default_form_builder`, or pass
`builder:` per form.

- `field(method, label, required:, hint:, as:, &block)` — the control comes from
  `as:` (any builder method), or from the block when you pass one. An invalid field
  gets `aria-invalid="true"` and its errors underneath, read as a sentence.
- `group(inline: false)` — lay the contained fields out in a row.
- `errors_summary` — the record's whole-object (`:base`) errors.
- `check_box_field`, `check_box_collection` — a checkbox with its label beside it.
- `submit` — conjugates its label for the length of the submit ("Save" → "Saving…",
  "Add label" → "Adding label…") via `data-turbo-submits-with`. Pass
  `submitting: false` to leave it alone, or a string to choose it. A block supplies
  your own button content, e.g. an icon.
- `form_value_for` — the value to show, whether the object is a model or something
  hash-ish, preferring what the user actually typed.

**What the control looks like is not decided here.** Apps style inputs in
incompatible ways — a class on every input, or a bare-element rule — and a
component library that picked one would be wrong in the other. So the builder emits
structure and the gem's CSS styles only the label, hint and error. Point your own
input rules at `.UnmagicField` to give its controls your look:

```css
.field,
.UnmagicField {
  /* your existing input rules */
}
```

The submit button's classes come from a seam, so it wears your own button:

```ruby
config.submit_class = ->(_view, variant) { variant == :primary ? "btn btn-primary" : "btn" }
```

## Live tables

A table whose rows a Turbo Stream keeps up to date needs the column definitions in
a place both the page render and a single broadcast row can reach, so they move
into a partial that takes a `table` local and does nothing but declare them:

```erb
<%# tasks/_columns.html.erb %>
<% table.column "Task", width: "30%" do |task| %>
  <%= link_to task.kind, task %>
<% end %>
<% table.column "Status" do |task| %>
  <span class="badge"><%= task.status %></span>
<% end %>
```

The page renders the table with them, names the `<tbody>` so a stream can target
it, and gives the rows one id prefix:

```erb
<%= turbo_stream_from "tasks" %>

<%= table_for @tasks, columns: "tasks/columns", rows_id: "task_rows",
      row_id: ->(task) { "task_#{task.id}" } do |table| %>
  <% table.empty "Nothing has run yet." %>
<% end %>
```

A broadcast renders one row from the same partial:

```erb
<%# tasks/_row.html.erb %>
<%= row_for task, columns: "tasks/columns", row_id: ->(task) { "task_#{task.id}" } %>
```

```ruby
class Task < ApplicationRecord
  after_create_commit :broadcast_row
  after_update_commit :broadcast_row

  private
    def broadcast_row
      broadcast_action_to "tasks", action: :upsert, target: "task_rows",
        attributes: { order: "desc" }, partial: "tasks/row", locals: { task: self }
    end
end
```

`upsert` is a Turbo Stream action this gem ships. Import it once:

```js
// app/javascript/application.js
import "unmagic/components/upsert"
```

It merges `append` and `replace`. If an element with the incoming id is already in
the document it is replaced in place, so a record that is both server-rendered and
broadcast never duplicates. Otherwise it is inserted at the position its id sorts
to, so out-of-order delivery still lands in order — which assumes time-ordered ids
(UUIDv7, ULID). `order="desc"` flips the comparison for a newest-first list.

**`row_id:` matters over an STI collection.** `dom_id` names the record's own
class, so subclasses get different prefixes and the rows sort by type rather than
by id. Give every row one prefix and the time-ordered id decides.

The companion `details` row is not broadcast: a stream action carries one element,
and the pair is a page-render concern.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome at
https://github.com/unreasonable-magic/unmagic-components.

## License

Available as open source under the terms of the [MIT License](LICENSE).
