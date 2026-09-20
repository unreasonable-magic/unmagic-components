# `pagination`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: the `pagination` seam and `table_for`, which draws
> one under itself; `infinite_scroll` (the other way to get more)

## Purpose

Links to the pages around this one, for anything that pages like Pagy. It is
what a table draws under itself, now with numbers.

## API

```erb
<%= pagination @pagy %>
<%= pagination @pagy, window: 1, turbo_frame: "results" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `pager` (positional) | Answers `previous`, `next`, `page_url`; and `page`, `last` for numbers | — | Anything else renders nothing |
| `window:` | Integer | `2` | Pages either side of the current one; first and last always show |
| `turbo_frame:` | String | `nil` | Points every link at a frame with `turbo_action: advance` |
| `label:` | String | I18n "Pagination" | The `<nav>`'s name |

One page renders nothing. Other options go on the `<nav>`.

## Markup

```html
<nav aria-label="Pagination" class="UnmagicPagination">
  <a class="UnmagicPagination__link" rel="prev" href="?page=5">Previous</a>
  <ol class="UnmagicPagination__pages">
    <li class="UnmagicPagination__page"><a class="UnmagicPagination__number" aria-label="Page 1" href="?page=1">1</a></li>
    <li class="UnmagicPagination__page"><span class="UnmagicPagination__gap" aria-hidden="true">…</span><a …>5</a></li>
    <li class="UnmagicPagination__page"><span class="UnmagicPagination__number" aria-current="page">6</span></li>
    …
  </ol>
  <span class="UnmagicPagination__count">6 of 12</span>
  <a class="UnmagicPagination__link" rel="next" href="?page=7">Next</a>
</nav>
```

## Accessibility

A labelled `<nav>`; the current page is `aria-current`; each number is named
"Page n"; the arrows carry `rel`; a disabled arrow is a `span` with
`aria-disabled`. Gaps are hidden from readers.

## Styling

Section **Pagination**: `__pages`, `__page`, `__gap`, `__number`, `__count` on
top of the existing `__link`.

## Small screens

Below `sm` the numbers hide and `__count` ("6 of 12") shows between the arrows.
Links and numbers are 44px tall on a coarse pointer.

## I18n

`unmagic.components.pagination.label`, `.previous`, `.next`, `.page` ("Page
%{page}"), `.of` ("%{page} of %{last}").

## Specs

`spec/unmagic/components/navigation_spec.rb`.
