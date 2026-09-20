# `chart`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: toybox's `ChartsHelper` (the source), `table_tag` (the
> numbers under it), `tooltip` (not used: the browser's own `<title>` is)

## Purpose

Columns over a set of labels, stacked where there is more than one series, or a
line over time. Inline SVG built in Ruby rather than a charting library: a bar is
a rectangle, and everything a library adds (a script, a build, a canvas nobody
can read) is the wrong trade for thirty numbers.

## API

See the helper's comment. `chart(series, labels:, type:, format:, title:, width:,
legend:, table:, max:, label_format:)`; a series is `{ label:, values:, total:,
slot: }`.

## Markup

`<figure class="UnmagicChart UnmagicChart--column">` → `<figcaption>` (title,
legend `ul`) → `<svg role="img" aria-label viewBox="0 0 720 200">` (gridlines,
`g.UnmagicChart__column` with a `<title>` and a transparent hit rect per column,
`path.UnmagicChart__mark--n` per segment, axis labels) → `<details>` with the
numbers as a `table_tag`.

## Accessibility

The SVG is an image named by the title; every column has a native tooltip; the
numbers are a real table under a disclosure, so nothing is only reachable by
hovering or by sight. Colour is never the only carrier: the legend names each
series and the table repeats every value.

## Styling

Section **Charts**: slot colours as `--unmagic-chart-series-1..6` knobs set on
`.UnmagicChart` from the palette, stepped separately for dark; ink, grid and
axis one shade off the surface. Marks dim on hover where hover exists.

## Small screens

The SVG scales to its box with `viewBox`, text included, so a full-width chart
on a phone shrinks its axis; use `width: 300` for one that must stay readable
small. The table under it is a `table_tag`, which stacks.

## Specs

`spec/unmagic/components/layout_pieces_spec.rb`.
