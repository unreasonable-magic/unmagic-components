# `<unmagic-optimistic>`

> Status: built
> Tier: 2 (small element)
> Relates to: the `upsert` stream action and `<uuid-input>`, which it completes

## As built

Where the build differs from this note:

- The placement rule lives in `unmagic/components/placement`, which `upsert.js` now imports too.
- The id element is the gem's `<unmagic-uuid-input>`.
- It doesn't skip an already-prevented submit: Turbo prevents the native one in order to send it itself.
- The failure event from the open question isn't built.

## Purpose

Draws a form's submission before the server has heard of it, by cloning a
`<template>` inside the form and placing it by id — the same reconcile-by-id
contract the gem's `upsert` stream action already uses. If an element with the
clone's id is already on the page it is replaced where it stands; otherwise it
is appended to a container. Either way the server then broadcasts the real
element under that id and the two become one.

For a form whose result the page can already draw: a chat message, a comment, a
row in a list. Not for a form whose result the server computes (a total, a slug,
a generated name) — an optimistic render that guesses those is a lie the upsert
then corrects in front of the reader.

The gem ships both other thirds of this contract already. `<uuid-input>` mints
the id the record will be created under, and `upsert` reconciles the broadcast
against it. This is the missing client half, and it exists in hooops and toybox
as the same Stimulus controller with 26 differing lines between them.

## API

```erb
<%# A new record appended to a list %>
<%= form_with model: Message.new, url: messages_path do |form| %>
  <unmagic-optimistic container="#entries">
    <uuid-input name="message[client_id]"></uuid-input>
    <%= form.text_area :content, required: true %>

    <template>
      <div data-optimistic-id="message[client_id]">
        <p data-optimistic-text="message[content]"></p>
      </div>
    </template>
  </unmagic-optimistic>
<% end %>

<%# Replacing an element that is already on the page, and not scrolling to it %>
<unmagic-optimistic container="#entries" scroll="false">…</unmagic-optimistic>
```

| Attribute | Values | Default | Notes |
|---|---|---|---|
| `container` | CSS selector | — | Where a *new* element is appended. Required |
| `scroll` | `true`, `false` | `true` | Scroll the inserted element into view |

Inside the template:

| Attribute | Takes |
|---|---|
| `data-optimistic-id` | The element's `id`, from the named field's value |
| `data-optimistic-text` | The element's `textContent`, from the named field's value |

Both name a form field by its `name`, not by a selector, so the template reads
like the form it belongs to.

The element listens for `submit` on the form it is inside — it does not need to
be the form itself, which is what lets a `class="contents"` form keep its own
layout. A `required` field keeps an empty form from submitting, so there is
never a stray optimistic element with no record coming to reconcile it.

## Markup

None of its own; `display: contents`. What it inserts is entirely the
template's.

```html
<unmagic-optimistic container="#entries">
  <!-- the form's own fields -->
  <template>
    <div data-optimistic-id="message[client_id]">…</div>
  </template>
</unmagic-optimistic>
```

## Accessibility

- The inserted element is ordinary content in the reading order; nothing is
  hidden from assistive technology and nothing is announced twice when the
  server's version replaces it (the replacement carries the same id and the same
  text).
- Scrolling the inserted element into view does not move focus. Focus stays in
  the composer, where the reader left it, so they can keep typing.
- An optimistic element is conventionally dimmed until confirmed (both
  applications use `opacity-60`). That is the caller's class on the template,
  not the gem's: the dimming has to disappear when the server's version lands,
  and the server's version is the caller's markup.

## Styling

CSS section: **Optimistic**, one rule.

```css
unmagic-optimistic { display: contents; }
```

## Behaviour (JavaScript)

`<unmagic-optimistic>` — reads `container` and `scroll`.

- On the form's `submit`: clone the template, fill `data-optimistic-id` and
  `data-optimistic-text` from the named fields, then place the clone.
- Placement is `upsert`'s rule exactly: replace by id if present, otherwise
  append to `container`. The two implementations must not be allowed to drift,
  so the placement itself moves into a module both `upsert.js` and this element
  import — this is the "shared helpers that aren't elements" case in the
  principles.
- Fires `unmagic-optimistic:insert` with the inserted element, bubbling.
- Turbo:
  - The listener is on the form and added in the constructor, so a moved element
    never doubles it up.
  - `turbo:before-cache` removes nothing: an optimistic element that was never
    confirmed is a real problem, and hiding it in the snapshot would hide the
    bug rather than the element.
  - Needs Turbo, for the broadcast that reconciles what it drew.

## I18n

None.

## Specs

No JavaScript specs. See Preview.

## Preview

Page: `elements`. A form that appends bubbles to a list, with a checkbox that
delays the "server" response so the dimmed state is visible, and a second form
whose template carries an id already on the page so the replace path can be
seen.

By hand:

- Submitting draws the bubble at once, dimmed, and it settles when confirmed.
- Submitting twice quickly draws two, each under its own minted id.
- The replace path swaps in place rather than appending.
- `scroll="false"` leaves the viewport alone.
- Submitting an empty required field draws nothing.

## Open questions

- What should happen when the submission fails? Today both applications leave
  the optimistic element on the page, dimmed forever. Proposed: fire
  `unmagic-optimistic:fail` on `turbo:submit-end` with `success: false` and let
  the caller decide, since removing it silently would throw away what the reader
  typed.
