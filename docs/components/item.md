# `item`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `card` (holds a list of them, flush), `avatar` (a media), `table_for` (rows with columns; this is rows without)

## Purpose

A row about one thing, wherever a list shows it: the picture on the left, the
name over a line about it, flags beside the name, and whatever the list wants
on the right. The media-object shape every app draws by hand.

## API

`item(title:, description:, href:, mono:) { |i| i.media {}; i.meta {}; i.actions {}; … }`;
`title` and `description` also as block parts.

## Markup

`div.UnmagicItem[--link][--mono]` → `div.__media` → `div.__main` (`div.__heading`
with `a|span.__title` + meta; `div.__description`; body) → `div.__actions`.
With `href:` the title link's `::after` stretches over the row; the actions
sit above it (`z-10`), so they stay their own targets.

## Accessibility

The row's link is the title's, named by it; the actions are separate controls.
The description clamps to two lines visually and is read in full.

## Small screens

Description clamps to two lines; actions keep their 44px targets; the media is
a fixed 48px square.

## Specs

`spec/unmagic/components/layout_pieces_spec.rb`.
