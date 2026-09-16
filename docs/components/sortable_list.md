# `sortable_list` and `sortable_handle`

> Status: built
> Tier: 3 (large)
> Replaces or relates to: hooops' `<sortable-list>`, `<sortable-item>` and drag
> session, which this extracts; [board](board.md), built on it; the
> [unmagic-sortable](https://github.com/unreasonable-magic/unmagic-sortable) gem,
> which owns the server half

## Purpose

A list whose items a person can put in their own order: interview steps,
screenshots, a shortlist, the cards in a board's column. Items can be dragged by
pointer or moved by keyboard, within the list or into another list sharing its
namespace. A drop posts only the moved item and its new neighbours, so the server
writes one row.

It isn't for ordering the server decides, which is `table_for`'s sort links, or for
choosing items, which is a checkbox list.

## Where it came from

hooops built this as three custom elements and a pointer-driven drag engine, with
no Stimulus. That's already this gem's shape, so the engine came across nearly
whole. Its drop contract (`moved`, `original`, `prev`, `next`, plus the list's
params) is kept exactly, so hooops can move onto the gem without touching its
endpoint. Building a board on it showed what hooops never needed:

- **Lists inside items.** A board's card list sits inside its column's item.
  hooops found an item's handle, and a list's params, without regard to nesting,
  so a column grabbed a card's handle and a card list lost its column param.
- **Dropping past an inner list.** A column dragged over a card list has to land
  in the board's list, not stop at the card list that won't take it.
- **Keyboard reordering.** hooops had none, which leaves reordering
  unavailable to anyone who can't drag. The principles require keyboard parity.
- **Scrolling at the edges while dragging, and Escape to cancel a drag.**
- **Morph refreshes.** A Turbo refresh resets attributes the element added
  (tabindex, `aria-describedby`), so it re-applies them after every morph.

## API

```erb
<%= sortable_list namespace: "cards", params: { column_id: column.id }, label: column.name do |list| %>
  <% column.cards.ordered.each do |card| %>
    <%= list.item(card) do %>
      <%= sortable_handle label: "Move #{card.title}" %>
      <%= link_to card.title, card %>
    <% end %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `namespace:` | string | `nil` | Lists sharing one exchange items |
| `params:` | hash | `{}` | Posted with a drop into this list |
| `url:` | path | `config.sortable_url` | Where drops are posted; `nil` posts nothing |
| `orientation:` | `:vertical`, `:horizontal`, `:grid` | `:vertical` | Validated; decides which arrows move |
| `label:` | string | `nil` | The list's name in announcements |

- `list.item(record = nil, key:, rank:, label:, **options) { }`: the key and
  rank come from `config.sortable_item` for a record, or from `key:`/`rank:`.
  `label:` is the item's name in announcements; its text otherwise.
- `sortable_handle(label:)`: an icon button that is the item's drag grip and
  keyboard stop.
- Other options go on the `<unmagic-sortable-list>`.

Two new settings on `Configuration`, which unmagic-sortable fills in:

- `sortable_item`, called with `(view, record)`. It returns `{ key:, rank: }` and
  defaults to the record's id and `sortable_rank`.
- `sortable_url`, called with `(view)`. It defaults to `nil`.

## Markup

```html
<unmagic-sortable-list namespace="cards" url="/sortable/ordering" label="To do"
                       data-sortable-picked="Picked up {item}…" …
                       class="UnmagicSortableList UnmagicSortableList--vertical">
  <unmagic-sortable-param name="column_id" value="3"></unmagic-sortable-param>
  <unmagic-sortable-item key="…" data-sortable-rank="1.5" data-sortable-label="Write the brief"
                         class="UnmagicSortableItem">…</unmagic-sortable-item>
</unmagic-sortable-list>
```

The words announced are rendered by the server, so they're translated like
everything else. A child marked `data-sortable-tail` stays at the end of the list
whatever is dropped; a board's "Add a list" tile uses it.

## The drop

The drop fires `unmagic-sortable:move` on the item. It bubbles, can be cancelled,
and carries `{ key, original, prev, next, params }`. Unless it's cancelled and
the list has a `url`, the list PATCHes that url:

| Field | |
|---|---|
| `moved` | The item's key |
| `original` | Its rank when it was picked up; the server refuses a stale move |
| `prev` | The rank of the item now before it; blank at the start |
| `next` | The rank of the item now after it; blank at the end |
| _each param_ | This list's params |

It goes as a Turbo form submission, so the server's refresh (unmagic-sortable's
endpoint sends one) morphs the page to the order that was saved.

## Accessibility

- **Keyboard,** after the drag-and-drop patterns in dnd-kit and
  react-beautiful-dnd:
  - Space or Enter on an item's handle, or on the item when it has none, picks
    it up.
  - The arrows along the list move it: Up and Down in a vertical list, Left and
    Right in a horizontal one, all four in a grid.
  - The arrows across the list move it to the same position in the neighbouring
    list that accepts it.
  - Space or Enter drops it. Escape, or moving focus away, puts it back where it
    was.
- **Focus** stays on the handle throughout. The engine hands focus back after
  each move, since moving an element can drop its focus.
- **Announcements:** picking up, each move, dropping and cancelling are
  announced in an assertive live region, with the item, its position, the count
  and the list's name. Each keyboard stop is described by the list's
  instructions.
- **An item without a handle** gets `tabindex="0"` and is its own stop. With a
  handle, the handle is.
- **WCAG 2.5.7 (Dragging Movements):** the keyboard route is a
  single-pointer-free alternative. An app should still offer a non-drag way to
  move an item between lists on touch, such as a menu.
- **Touch:** a finger lifts an item with a long press (250ms, holding within
  8px). A swipe that moves sooner scrolls the page and drags nothing, and a tap
  still reaches whatever was tapped. Once lifted, the page stops scrolling under
  the finger for the rest of the gesture, and Android vibrates briefly.
  - The `sortable_handle` grip is `touch-action: none`, so a finger drags it at
    once. Any other handle, such as a board column's header, leaves scrolling
    alone and waits for the long press too. The element reads which from the
    handle's computed `touch-action`.
  - On a coarse pointer, items don't select text or open the system's link
    menu, since a long press would otherwise do both.

## Styling

CSS section: **Sortable**. Variants, declared at the top of `engine.css`,
prefixed so they can't collide with a host's:

| Variant | Matches |
|---|---|
| `sortable-dragging:` | The copy following the pointer, or anything in it |
| `sortable-placeholder:` | The item left in place while a pointer drags it |
| `sortable-lifted:` | The item a keyboard is holding |
| `sortable-active:` | A list that can take the current item, or its ancestor |
| `sortable-over:` | The list under the pointer, or its ancestor |

The defaults are:

- The copy is fixed, pointer-transparent and lifted with a `drop-shadow` (which
  follows rounded corners).
- The placeholder is at 40% opacity, and the lifted item is outlined.
- Handles show a grab cursor, and nothing on the page is selectable while a
  drag is on.

There is no motion: the item moves as the pointer does, and there's nothing to
switch off under reduced motion.

## Behaviour (JavaScript)

- `sortable_list.js` — `<unmagic-sortable-list>`
- `sortable_item.js` — `<unmagic-sortable-item>`
- `sortable_param.js` — `<unmagic-sortable-param>`
- `sortable_session.js` — the engine, one drag at a time, used by the elements
  only through their public methods.
- `sortable.js` — imports all of them.

Pointer drags:

- A press on a handle drags straight away. A press elsewhere on a handle-less
  item waits for four pixels of movement, so a click still clicks. A press on a
  text field never drags.
- With a handle, a press on the handle's own buttons and links (a column
  header's menu) doesn't drag.
- The target is the innermost list under the pointer that accepts the item.
  The slot is the near side of the nearest item, in reading order for wrapping
  rows.
- It scrolls anything scrollable under the pointer within 56px of an edge,
  faster nearer the edge, and the page too.
- After the drop it swallows the click that follows, so dragging a linked card
  doesn't open it.
- `pointercancel`, Escape, or Turbo caching the page put the item back.

Touch drags are described under Accessibility. A pending press doesn't capture
the pointer, so the browser can still pan; if it does, `pointercancel` drops the
press. A non-passive `touchmove` listener stops the page scrolling only once the
item has lifted.

## Specs

`sortable_board_spec.rb`:

- The list's attributes and announcements, its params and its items.
- The `sortable_item` and `sortable_url` settings, and `key:`, `rank:` and `url:`
  overriding them.
- Orientation validation, and an item with no key.
- The handle's markup.

The behaviour was checked in Chrome from the preview:

- a move within a list, a move between lists, and a column move
- Escape during a pointer drag
- keyboard pick up, move, move across, drop and cancel, with their announcements
- a handle's sibling button staying clickable, and the move event
- on an emulated phone:
  - a swipe over a card or a column header scrolls the page and drags nothing
  - a tap drags nothing
  - a long press lifts a card without scrolling the page, and moves it within a
    column and into the column under the finger, with the board scrolling at its
    edge
  - a long press on a header moves a column
  - a grip drags without the hold

## Preview

The Sortable list page shows a list with handles and a live readout of the move
event, a grid, and two lists sharing a namespace.
