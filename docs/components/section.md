# `section`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `page_header` (the top of the page; this is each run below it), `card`

## Purpose

A titled run of a page: Files, Metadata, Sources. A small uppercase heading
with what qualifies it beside it, the button that acts on the run hard right,
then the run.

## API

`section(title, spacing: :normal | :tight | :none, heading: :h2) { |s| s.aside {}; s.actions {} … }`.

## Markup

`<section class="UnmagicSection UnmagicSection--normal">` → `div.__head`
(`div.__heading` with `h2.__title` + aside; `div.__actions`) → the body.

## Small screens

The head wraps, so the actions drop under the heading when the row is too
narrow for both.

## Specs

`spec/unmagic/components/layout_pieces_spec.rb`.
