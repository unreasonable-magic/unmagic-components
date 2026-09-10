# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `table_for` passes any option it doesn't recognise to the `<table>` element, so a
  view can set `class:`, `data:` or ARIA attributes without a wrapper. `id:` still
  names the deferred turbo frame.
- `table.empty` and `table.no_results` take extra options and hand them to the
  configured `empty_state` seam, for an app whose blank slate needs more than a
  message (an icon, say).
- Live tables. `columns:` moves a table's column definitions into a partial, and
  `row_for` renders the single `<tr>` those columns produce for one record, so a
  Turbo Stream broadcast and the page render cannot drift. `rows_id:` puts an id
  on the `<tbody>` for a stream to target, and `row_id:` overrides the row's own
  id — needed over an STI collection, where `dom_id` names each subclass and the
  rows would sort by type rather than by id.
- `FormBuilder`, the chrome around a form control: the `field` wrapper with its
  label, required marker, hint and error line; `group` for a row of fields;
  `errors_summary`; `check_box_field` and `check_box_collection`; `form_value_for`;
  and a `submit` that conjugates its own label while submitting ("Save" ->
  "Saving…") through `data-turbo-submits-with`. It deliberately does not style the
  control itself — apps disagree about whether inputs carry a class or are styled
  bare — so it emits structure and leaves appearance to the host.
- The `upsert` Turbo Stream action (`import "unmagic/components/upsert"`), which
  merges `append` and `replace`: a row already on the page is replaced in place,
  and a new one is inserted at the position its id sorts to. `order="desc"` on the
  stream tag flips that for a newest-first list.

## [0.1.0] - 2026-09-10

### Added

- `table_for`, a declarative index-table builder: columns with blocks or attribute
  names, sortable headers with `aria-sort`, right/centre alignment, numeric columns,
  `<colgroup>` width pinning, companion detail rows, and two flavours of empty state.
- Deferred tables — `table_for collection, defer: true` renders a skeleton inside a
  Turbo Frame without touching the collection, then loads the real rows into it.
- `table_tag`, the underlying primitive, for static tables built from plain arrays.
- `detail_list`, a description-list builder with inline and stacked variants.
- Theming through `--unmagic-*` CSS custom properties, with every value falling back
  to a Tailwind palette default so the components look right unconfigured.
- Configurable empty-state, pagination and Pagy seams so the gem depends on neither
  Pagy nor any host helper.

[Unreleased]: https://github.com/unreasonable-magic/unmagic-components/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/unreasonable-magic/unmagic-components/releases/tag/v0.1.0
