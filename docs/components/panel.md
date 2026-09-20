# `panel`

> Status: built
> Tier: 2 (uses `tabs`' element; nothing of its own)
> Replaces or relates to: `card` (its box, through the new `header` part), `tabs`
> (its switcher, in the new `bar` style), `code_view` (what usually sits in one)

## Purpose

One box with a row of switcher buttons across its top bar and the open one's
content below: a repository's README beside its brief and style guide, a file's
source beside its preview and metadata. It is the shape three applications drew
by hand as "a card with a tab bar in its header".

Two kinds of tab, exactly as `tabs` has them. **In-page tabs** switch panels with
no round trip. **Link tabs** (`href:`) are pages of their own: the URL names the
open one, the server draws only that one, and the address can be sent to
someone. It is not for a settings page's sections (that is `tabs` on their own)
or for a wizard (`steps`).

## API

```erb
<%# Switched in the page %>
<%= panel id: "notes" do |panel| %>
  <% panel.tab "README", icon: :book_open %>
  <% panel.tab "Agents", icon: :bot %>
  <% panel.panel { markdown @readme } %>
  <% panel.panel { markdown @agents } %>
<% end %>

<%# Each tab a page; the block is the open one's body %>
<%= panel flush: true do |panel| %>
  <% panel.tab "Source", href: file_path(@file, view: :source), active: @view == :source, icon: :code %>
  <% panel.tab "Preview", href: file_path(@file, view: :preview), active: @view == :preview, icon: :eye %>
  <%= render "files/#{@view}", file: @file %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | String | random | The element's id; with one, in-page tabs remember the choice (see `tabs`) |
| `flush:` | Boolean | `false` | Drops the body's padding, for a code view or a table that runs to the edges |

- **Parts are `tabs`'**: `panel.tab(label, icon: nil, disabled: nil, href: nil, active: false)`
  and `panel.panel { … }`. `icon:` is a symbol from the gem's Lucide set or
  rendered markup from the host's own icons.
- Other options go on the outer element.
- Validation is `tabs`': mismatched panels, or mixing `href:` with panels, raise
  `ArgumentError`.

## Markup

In-page tabs, so the whole card is the `<unmagic-tabs>` element:

```html
<unmagic-tabs id="notes" class="UnmagicCard UnmagicPanel UnmagicTabs UnmagicTabs--bar">
  <header class="UnmagicCard__bar UnmagicPanel__bar">
    <div role="tablist" class="UnmagicTabs__list">
      <button type="button" role="tab" id="notes_tab_0" class="UnmagicTabs__tab" aria-controls="notes_panel_0" aria-selected="true" tabindex="0">
        <svg class="UnmagicIcon UnmagicTabs__icon" aria-hidden="true">…</svg>README
      </button>
      …
    </div>
  </header>
  <div class="UnmagicCard__body UnmagicCard__body--flush">
    <div role="tabpanel" id="notes_panel_0" class="UnmagicTabs__panel" aria-labelledby="notes_tab_0" tabindex="0">…</div>
    <div role="tabpanel" id="notes_panel_1" … hidden>…</div>
  </div>
</unmagic-tabs>
```

Link tabs: a `<section class="UnmagicCard UnmagicPanel">` whose bar holds
`<nav class="UnmagicTabs UnmagicTabs--bar">` of links, `aria-current="page"` on the
open one, and whose body is the block.

## Accessibility

- The ARIA tab pattern, from `tabs`: the server renders roles, `aria-controls`
  and `aria-labelledby`; the element moves the selection with a click or the
  arrow keys, Home and End. `tabs.js` now finds a list and its panels anywhere
  inside its element, so the bar and the body can be separate boxes.
- Link tabs are navigation with the current page marked; no script.
- Icons are `aria-hidden`; the label is the name.

## Styling

- Section **Panels** in `engine.css`: `UnmagicPanel`, `UnmagicPanel__bar`,
  modifier `--flush`. The box is `UnmagicCard`'s; the bar is the new
  `UnmagicCard__bar`, drawn tight (`px-1 py-0.5` around a list that has its own
  `p-1`, so a focus ring isn't clipped by the scrolling list).
- The tabs are `UnmagicTabs--bar`: no track, pill tabs, the selected one
  `neutral-100`/`neutral-800`.
- Colours: the card's and the tabs'. No new theme variables.

## Small screens

- The bar's list is one row that scrolls sideways (`overflow-x: auto`, snap
  points, no scrollbar drawn), rather than wrapping into two rows of pills.
- `tabs.js` scrolls the selected tab into the middle of the row on connect and
  on each change, and does the same for a bar of links marking the current
  page, so the open tab is never off the edge.
- Tabs keep `py-1.5`, which with the bar's padding gives a 44px row on a phone.

## Behaviour (JavaScript)

`tabs.js`, unchanged in API: `import "unmagic/components/tabs"`. Two additions
for this component: tabs are found by nearest `<unmagic-tabs>` rather than by
direct children, and a `bar`-style list is scrolled to show its selected tab.

## I18n

None of its own.

## Specs

`spec/unmagic/components/panel_spec.rb`: the in-page structure (bar, list, body,
panels, ids), the link structure (section, nav, body), icons as symbols and as
markup, `flush:`, passthrough, and `tabs`' errors surfacing.

## Preview

Browser page `panel`: in-page notes with icons and a disabled tab; link tabs
around a flush code view. Check: arrow keys move between tabs and the body
follows; at a phone width the bar scrolls and the open tab is in view; dark theme.
