# `table.selectable` and `bulk_actions`

> Status: draft
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Checkbox Select All" (gap source). Builds
> on `table_for`, `row_for` and the `upsert` stream action.

## Purpose

Lets someone tick rows in an index table and act on all of them at once:
archive twelve jobs, or assign five tickets. A leading checkbox column goes on
the table and a toolbar sits above it. The toolbar shows how many rows are
selected and holds the actions. The header checkbox selects every row on the
page, and shows as mixed when only some are selected.

It is **not** for choosing values in a form. Use `check_box_collection` for
that. It doesn't select across pages either; see Open questions.

## API

The checkbox column is declared like any other column. On a live table it goes
in the columns partial, so `row_for` renders the same cell:

```erb
<%# jobs/_columns.html.erb %>
<% table.selectable form: "bulk_jobs" %>
<% table.column "Job" do |job| %><%= link_to job.name, job %><% end %>

<%# jobs/index.html.erb %>
<%= bulk_actions id: "bulk_jobs", url: bulk_jobs_path do |bulk| %>
  <% bulk.button "Archive", name: "operation", value: "archive" %>
  <% bulk.button "Delete", name: "operation", value: "delete", tone: :danger,
       data: { turbo_confirm: "Delete the selected jobs?" } %>
<% end %>

<%= table_for @jobs, columns: "jobs/columns", rows_id: "job_rows" %>
```

**`table.selectable`**

| Option | Values | Default | Notes |
|---|---|---|---|
| `form:` | id of a `bulk_actions` | required | Every checkbox carries `form="…"` |
| `name:` | string | `"ids[]"` | The submitted param |
| `value:` | `->(record)` | `record.to_param` | The submitted value |
| `label:` | `->(record)` | "Select row" | Each row checkbox's accessible name |

- Declared once per table. A second call raises `ArgumentError`.
- It is always the first column, whatever order it's declared in.
- It gets a fixed width so a deferred table's skeleton lines up.

**`bulk_actions(id:, url:, method: :post, **options, &block)`**

- `bulk.button(label, tone: :default | :danger, **button_options)` renders a
  `<button type="submit">`. `formaction:`, `formmethod:`, `name:`/`value:` and
  `data:` pass straight through.
- A Rails verb override is `name: "_method", value: "patch"` on the button.
  Rails reads `_method` from a submitter too.
- `bulk.count` is optional. Pass a block to place the count yourself; otherwise
  the count leads the toolbar.
- Other options go on the `<unmagic-bulk-actions>` element.
- **Empty collection:** `table_for` renders its empty state and no checkboxes,
  and the toolbar stays disabled.

## Markup

The checkboxes live in the table but belong to the toolbar's form through the
HTML `form` attribute. Submitting the form sends the ticked ids with **no
script**, and the table doesn't need to be inside the form. That matters
because a table may already contain `button_to` forms, and forms can't nest.

```html
<unmagic-bulk-actions class="UnmagicBulkActions" for="bulk_jobs"
    data-zero="No rows selected" data-one="1 row selected" data-other="%{count} rows selected">
  <form id="bulk_jobs" action="/jobs/bulk" method="post" class="UnmagicBulkActions__form">
    <input type="hidden" name="authenticity_token" value="…">
    <output class="UnmagicBulkActions__count" aria-live="polite">No rows selected</output>
    <div class="UnmagicBulkActions__actions">
      <button type="submit" name="operation" value="archive" class="UnmagicButton">Archive</button>
      <button type="submit" name="operation" value="delete" class="UnmagicButton UnmagicButton--danger">Delete</button>
    </div>
  </form>
</unmagic-bulk-actions>

<table class="UnmagicTable UnmagicTable--full UnmagicTable--fixed">
  <thead><tr>
    <th class="UnmagicTable__select">
      <input type="checkbox" form="bulk_jobs" class="UnmagicCheck" data-unmagic-bulk-all
             aria-label="Select all rows on this page" disabled>
    </th> …
  </tr></thead>
  <tbody id="job_rows">
    <tr id="job_01J…">
      <td class="UnmagicTable__select">
        <input type="checkbox" form="bulk_jobs" name="ids[]" value="01J…" class="UnmagicCheck"
               data-unmagic-bulk-row aria-label="Select row">
      </td> …
    </tr>
  </tbody>
</table>
```

- **Both checkboxes get their look** from
  `Components.configuration.control_class.call(view, :check)`, which returns
  `"UnmagicCheck"` by default, the same class `check_box_field` uses.
  - A host can return its own classes, or `nil` for the browser's own checkbox.
  - They stay real `<input type="checkbox">` elements.
- The header checkbox has no `name`, so it is never submitted.
- It renders `disabled` and the element enables it on upgrade, so without
  script it doesn't look like it works.

## Accessibility

- Native checkboxes. The header uses the tri-state pattern
  (`indeterminate = true` when some rows are ticked; see the
  [APG checkbox pattern](https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/)).
- Row checkbox names come from `label:`. The docs recommend
  `->(job) { "Select #{job.name}" }` so the names are distinct.
- The count is an `<output aria-live="polite">`, so a change is announced once
  per click, not per row.
- The action buttons are `aria-disabled="true"` while nothing is selected, and
  stay focusable so the reason is discoverable. A click then does nothing.

| Key | Where | Does |
|---|---|---|
| Space | any checkbox | Toggles (native) |
| Shift+Space, Shift+click | row checkbox | Sets every row between the last one toggled and this one to its state |
| Escape | inside the toolbar | Clears the selection, focus stays |

## Styling

- CSS section **Bulk actions**:
  - `UnmagicBulkActions`, `__form`, `__count`, `__actions`
  - `UnmagicTable__select`: a narrow centred cell, and the column's `width`
- `.UnmagicBulkActions[data-selected] .UnmagicBulkActions__count` uses
  `neutral-900`/`dark:neutral-100`, and `neutral-500` when nothing is selected.
- **The checkboxes** use the shared `UnmagicCheck` rule from **Forms**, with
  states from `:checked`, `:indeterminate`, `:disabled`, `[aria-invalid=true]`
  and `:focus-visible`. This section adds nothing to the checkbox itself.
- **A selected row** is styled from
  `.UnmagicTable tbody tr:has(> .UnmagicTable__select > [data-unmagic-bulk-row]:checked)`
  with `neutral-50`/`dark:neutral-800/50`, so no state class drifts from the checkbox.
  - The attribute hook is used rather than the look class, so the highlight
    still works when a host opts out of `UnmagicCheck`.
- Colours: palette with `dark:` variants only (`neutral-900`/`dark:neutral-100`,
  `neutral-500`, `neutral-50`/`dark:neutral-800/50`, `neutral-200`/`dark:neutral-800`).
- Motion: none.

## Behaviour (JavaScript)

The element is `<unmagic-bulk-actions for="FORM_ID">`. It finds its checkboxes
by `[form=FORM_ID]` anywhere in the document, so the table and toolbar can sit
far apart.

- **On connect:**
  - enables the header checkbox
  - reads the current selection from the checked boxes
  - sets the count, the header's indeterminate state and `data-selected`
- **Listening:** `change` and `click` (for the shift range) are delegated from
  `document` in `connectedCallback` and removed in `disconnectedCallback`.
- **Header toggle:** ticks or unticks every enabled row checkbox.
- **Count:** uses `Intl.PluralRules` to pick `data-zero`, `data-one` or
  `data-other`.
- **Events:** fires `unmagic-bulk-actions:change` with `{ ids }`.

### Turbo

- **Streamed rows.** `upsert` swaps a whole `<tr>`, which would drop a tick. The
  element keeps the selection as a `Set` of values. A `MutationObserver` on
  each `tbody` that holds its checkboxes re-ticks a row whose value is in the
  set, and drops values whose row has left the document.
- **`turbo:morph`.** Re-applies the set to the checkboxes, because the morph
  resets them to the server's unticked state. Then recounts.
- **`turbo:before-cache`.** Clears the selection and unticks everything, so Back
  doesn't restore a stale selection that no longer matches the count.
- **Snapshot clones.** Nothing is generated, so nothing needs removing; connect
  recomputes from the DOM.
- **After a successful submit** (`turbo:submit-end`), clears the selection. The
  response usually refreshes the table.
- **Dependencies:** none. It works without Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.bulk_actions.selected.zero` | "No rows selected" |
| `unmagic.components.bulk_actions.selected.one` | "1 row selected" |
| `unmagic.components.bulk_actions.selected.other` | "%{count} rows selected" |
| `unmagic.components.bulk_actions.select_all` | "Select all rows on this page" |
| `unmagic.components.bulk_actions.select_row` | "Select row" |

## Specs

In `spec/unmagic/components/bulk_select_spec.rb`:

- `table.selectable` adds a leading `th/td.UnmagicTable__select`, even when
  declared after other columns.
- Row checkboxes carry `form`, `name`, `value` (default and lambda) and the
  label. The header has `data-unmagic-bulk-all`, no `name`, and `disabled`.
- Both checkboxes carry `UnmagicCheck` by default. A configured `control_class`
  receives `:check`, its return value replaces the class, and `nil` renders no
  look class.
- `row_for` with the same columns partial renders the checkbox cell, using the
  `spec/views` partial.
- `skeleton` (`defer: true`) keeps the select column's width and header.
- A second `selectable` raises `ArgumentError`, as does a missing `form:`.
- `bulk_actions` renders a form with that id, the CSRF token, the method
  override for `method: :patch`, the `<output>` and each plural template.
- `bulk.button` passes `formaction`, `name`/`value` and `data`, and adds the
  danger class for `tone: :danger`. An unknown tone raises `ArgumentError`.

## Preview

The index (`/`, "Loaded") gets a toolbar and a selectable column. The action
posts to a preview endpoint that flashes a toast naming the ids.

Check by hand:

- Tick rows, then check the header's mixed and full states and the count.
- Shift-range selection works.
- Submit with JS disabled: the ids still arrive.
- Leave the page and come back: the selection is cleared.
- Keyboard only.
- Dark theme.

## Open questions

- **Selecting across pages** ("Select all 240 matching"). This needs a server
  query token rather than ids. Build it now, or leave it until someone asks?
- Should the toolbar hide when nothing is selected, or stay visible but
  disabled? The proposal is disabled: no layout shift, and the actions stay
  discoverable.
