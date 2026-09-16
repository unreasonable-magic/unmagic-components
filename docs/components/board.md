# `board`

> Status: built
> Tier: 3 (large)
> Replaces or relates to: [sortable_list](sortable_list.md), which it's built on;
> hooops' deleted job kanban (`jobs/show/_kanban`)

## Purpose

A Trello-style board: columns of cards, both reorderable, with a way to add to
each. For a pipeline, a roadmap, anything whose items move through stages.

Not for a plain list; that's `sortable_list`. Not for a table of records by
status, where columns don't move and nothing is dragged.

## API

```erb
<%= board id: "roadmap" do |board| %>
  <% @columns.each do |column| %>
    <% board.column column, title: column.name, params: { column_id: column.id } do |col| %>
      <% col.actions { menu { |m| m.link "Rename", edit_column_path(column) } } %>
      <% column.cards.ordered.each do |card| %>
        <% col.card(card) { render card } %>
      <% end %>
      <% col.add url: cards_path, field: "card[title]", params: { "card[column_id]" => column.id } %>
    <% end %>
  <% end %>
  <% board.add_column url: columns_path, field: "column[name]" %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | string | required | Names the board, its lists' namespaces and its form ids |
| `url:` | path | `config.sortable_url` | Where drops post |
| `columns_url:` | path | `url:` | Where column drops post, if elsewhere |
| `sortable_columns:` | boolean | `true` | `false` fixes columns in place |
| `label:` | string | "Board" | The region's name |
| `column_height:` | CSS length | `75dvh` | How tall a column grows before its cards scroll |

- `board.column(record = nil, title:, key:, rank:, params:, count:) { |col| }`:
  `params:` are posted when a card lands in the column. `count:` is for a column
  showing fewer cards than it has.
- `col.card(record = nil, key:, rank:, label:, **options) { }`: takes what
  `sortable_list`'s `item` takes.
- `col.actions { }`: controls in the column's header, which stay clickable.
- `col.add(url:, field:, label:, placeholder:, params:, method:)` and
  `board.add_column(…)`: a one-field form, described below.
- Other options go on the root `<div>`.

`--unmagic-board-column-height` is the board's one knob, written by
`column_height:`.

## Markup

```html
<div id="roadmap" role="region" aria-label="Board" class="UnmagicBoard">
  <unmagic-sortable-list namespace="roadmap-columns" orientation="horizontal" class="… UnmagicBoard__columns">
    <unmagic-sortable-item key="…" data-sortable-label="To do" class="… UnmagicBoard__column">
      <section class="UnmagicBoard__panel" aria-labelledby="roadmap_column_…_title">
        <header class="UnmagicBoard__head" data-sortable-handle>
          <button class="… UnmagicBoard__grip" data-sortable-handle aria-label="Move To do">…</button>
          <h3 id="roadmap_column_…_title" class="UnmagicBoard__title">To do</h3>
          <span class="UnmagicBoard__count">3<span class="UnmagicVisuallyHidden"> cards</span></span>
          <div class="UnmagicBoard__actions">…</div>
        </header>
        <unmagic-sortable-list namespace="roadmap-cards" label="To do" class="… UnmagicBoard__cards">
          <unmagic-sortable-param name="column_id" value="3"></unmagic-sortable-param>
          <unmagic-sortable-item class="… UnmagicBoard__card">…</unmagic-sortable-item>
        </unmagic-sortable-list>
        <details class="UnmagicBoard__add">…</details>
      </section>
    </unmagic-sortable-item>
    <div class="UnmagicBoard__tail" data-sortable-tail>…Add a list…</div>
  </unmagic-sortable-list>
</div>
```

- **A column** is dragged by its whole header. The grip in the header is its
  keyboard stop. A card has no handle, so the whole card drags and is its own
  stop; put a `sortable_handle` in a card to change that.
- **Ids** are derived from the board's id and the column's key, so a morph
  refresh matches elements up rather than replacing them.

## The add forms

Trello's "Add a card" is a `<details>` that opens into a one-field form. The
field is an autogrowing textarea with the control class. `board.js`:

- focuses the field when the form opens
- submits on Enter; Shift+Enter makes a new line
- closes it on Escape or ×, returning focus to the toggle
- after a successful submit, resets the form and keeps it open and focused, so
  several can be added in a row

That last one needs the form to survive the refresh that follows. The field's
stable id keeps the element, and `board.js` cancels the morph of the
`<details>`' `open` attribute (`turbo:before-morph-attribute`), which the
server's markup doesn't have.

## Accessibility

- The board is a labelled region. Each column is a `<section>` named by its
  title, and the count reads "3 cards".
- Touch is `sortable_list`'s: press and hold a card or a column's header to lift
  it, and swipe to scroll. The header doesn't stop the page scrolling; only the
  grip does.
- Keyboard and announcements are `sortable_list`'s. Columns move with Left and
  Right. Cards move with Up and Down, and Left and Right move them across
  columns.
- The add toggle is a `<summary>`; closing the form returns focus to it.

## Styling

CSS section: **Boards**. Columns are `w-72` in a sideways-scrolling row. Both scrollers are `relative`,
so anything absolutely positioned inside them (the count's visually hidden word)
is clipped by them rather than widening the page. Neither contains overscroll:
Chrome applies that to a column that isn't overflowing, and a finger swiping over
it then couldn't scroll the page. A panel
is a neutral surface that grows to the knob, and its cards then scroll inside
it. The card list tints under the pointer during a drag. Cards are white with a
border, grab cursor and small shadow, tilted two degrees while dragged. The "Add
a list" tile is dashed.

## Behaviour (JavaScript)

`sortable.js` for the dragging, and `board.js` for the add forms, delegated from
`document`.

## Specs

In `sortable_board_spec.rb`:

- the region and the list of columns (namespace, orientation, url, the tail)
- a column's header handle, grip, count, actions and card list with its params
- counts, singular and plural
- the add forms, with their fields, params, stable ids and buttons
- fixed columns, a separate columns url, and the errors

## Preview

The Board page has a working board saved in the session. Drops, added cards and
added lists persist, and the server answers the same way unmagic-sortable does.
A second example shows cards with handles.

Checked in Chrome, light and dark:

- moving a card within a column and across columns
- moving a column by its header
- Escape during a drag
- a header menu still opening
- keyboard pick up, move, move across, drop and cancel
- adding a card with Enter and staying ready for the next
- everything surviving a reload

## Open questions

- **Moving a card without dragging.** A long press drags on touch, but should a
  card also get a "Move to…" menu built in, for anyone who can't drag at all?
  For now it's the host's, through `col.card`'s content.
- **Collapsing a column, and work-in-progress limits.** Trello has the first;
  neither is built.
