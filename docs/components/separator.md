# `separator`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `menu.divider` (a rule inside a menu)

## Purpose

A rule between two things: the line under a section, the "or" between two ways
to sign in, the upright tick between items in a row of metadata.

## API

```erb
<%= separator %>
<%= separator "or" %>
<%= separator orientation: :vertical %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label` (positional) | String | `nil` | A word on the rule |
| `orientation:` | `:horizontal`, `:vertical` | `:horizontal` | Validated |

Other options go on the element.

## Markup

A plain horizontal rule is an `<hr class="UnmagicSeparator">`. With a label, or
upright, it is `<div role="separator" class="UnmagicSeparator">`, with
`aria-orientation="vertical"` when upright and `<span class="UnmagicSeparator__label">`
for the word.

## Accessibility

`<hr>` is a separator already; the div says so. The word is real text, read
in place.

## Styling

Section **Separator**: the worded rule draws its line either side of the word
with `::before` and `::after`; `--vertical` is a 1px column that stretches to its
row.

## Small screens

Nothing to do; a rule is a rule.

## Behaviour (JavaScript)

None.

## Specs

`spec/unmagic/components/buttons_spec.rb`.
