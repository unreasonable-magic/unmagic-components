# `infinite_scroll` / `table_for … paginate: :infinite`

> Status: draft
> Tier: 2 (small element; here, no element: Turbo lazy frames)
> Replaces or relates to:
> - Rails Blocks "Infinite Scroll" (the gap source)
> - `table_for` (`defer:`, `rows_id:`), the `pagination` and `pagy_for` seams (`configuration.rb`), `Renderers::Pagination`

## Purpose

Loads the next page of a long list as the reader nears the end of it, instead of
making them click "Next". It is for feeds and logs, where the reader scrolls
rather than jumps to a page: activity, messages, an audit trail, search results
read top to bottom.

It is **not** for tables people sort, filter, or link to a page of. Use
`table_for`'s normal pager there, because infinite scroll loses the page in the
URL and pushes the footer out of reach.

## API

```erb
<%# A table: rows arrive in the table's own tbody %>
<%= table_for @events, rows_id: "event_rows", paginate: :infinite do |table| %>
  <% table.column "Event" do |event| %><%= event.name %><% end %>
<% end %>

<%# A plain list: the block renders one item %>
<%= infinite_scroll @messages, id: "messages", class: "grid gap-2" do |message| %>
  <%= render message %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `paginate:` (`table_for`) | `true`, `false`, a pagy, `:infinite` | `true` | `:infinite` needs `rows_id:`, or it raises `ArgumentError` |
| `id:` (`infinite_scroll`) | string | required | Names the list, and is the prefix of the page frames |
| `tag:` | `:div`, `:ul`, `:ol` | `:div` | Validated. Each item is wrapped in `<li>` when the tag is a list |
| `advance:` | boolean | `false` | Whether each page load pushes `?page=N` into the URL |

Rules:
- Paging uses the configured `pagy_for` seam, and only uses `previous`, `next`
  and `page_url`, so any pager that works with `table_for` works here.
- The frame id for each page is `"#{id}_page_#{pagy.next}"`. For a table the
  prefix is `rows_id`.
- `paginate: :infinite` can't be combined with `defer: true` in v1. It raises
  `ArgumentError`. See the open questions.
- Other options go on the list element.
- An empty collection renders the table's empty state, or nothing for a plain
  list. It never renders a frame.

### The action needs no special casing

This works the same way `defer:` does:
- On a normal request, the helper renders page 1 plus a lazy frame pointing at
  the next page.
- On a request whose `Turbo-Frame` header starts with `"#{id}_page_"`, the same
  helper renders only that frame. The frame holds an append stream with this
  page's rows and the lazy frame for the page after.

## Markup

A normal request, for page 1:

```html
<div id="messages" class="UnmagicInfinite">
  <article>…</article>
  <article>…</article>
</div>
<turbo-frame id="messages_page_2" class="UnmagicInfinite__more" loading="lazy"
             src="/messages?page=2" target="_top">
  <a href="/messages?page=2" class="UnmagicInfinite__link">Load more</a>
</turbo-frame>
```

A frame request, for page 2:

```html
<turbo-frame id="messages_page_2">
  <turbo-stream action="append" target="messages"><template>
    <article>…</article>
  </template></turbo-stream>
  <turbo-frame id="messages_page_3" class="UnmagicInfinite__more" loading="lazy" src="/messages?page=3" target="_top">
    <a href="/messages?page=3" class="UnmagicInfinite__link">Load more</a>
  </turbo-frame>
</turbo-frame>
```

On the last page, the inner frame is replaced by
`<p class="UnmagicInfinite__end">`, or omitted when `end:` is `false`.

What each piece does:
- **The frame sits outside the list.** A `<turbo-frame>` isn't valid inside a
  `<tbody>` or `<ul>`, so rows reach the list through a `<turbo-stream>`
  element, which Turbo runs as soon as it is connected, wherever it is.
- **Native pieces only.** `loading="lazy"` fetches when the frame nears the
  viewport. Turbo's own IntersectionObserver does that, so no element of ours
  is needed.
- **Without Turbo, the frame's contents are a plain link** to the next page,
  so every page is still reachable.
- **For a table, the rows are `builder.row(record)`**, the same `<tr>` that
  `row_for` renders, so live upserts and infinite pages can't drift apart.

## Accessibility

- **While a frame loads** it carries `aria-busy="true"`, which Turbo sets. The
  link text is swapped for a visually hidden "Loading more…" plus a spinner
  (see `spinner.md`).
- **Appended rows aren't announced one by one.** The end marker is a polite
  live region, so a screen reader hears "No more messages" once.
- **Keyboard:** the link stays focusable until it upgrades. Tabbing to it and
  pressing Enter loads the page the same way a scroll does.
- **A footer below an infinite list is unreachable by scrolling.** The preview
  and README say so, so the list goes last on the page.

## Styling

- **CSS section `Infinite scroll`.** Elements:
  - `UnmagicInfinite`: the list; no styles of its own, only a hook for the host
  - `UnmagicInfinite__more`: a centred block with padding
  - `UnmagicInfinite__link`: `button_classes(:ghost)` look
  - `UnmagicInfinite__end`: `neutral-500`, 0.75rem
- **State:**
  - `turbo-frame[aria-busy="true"] .UnmagicInfinite__link` hides the link and
    shows the spinner.
  - `turbo-frame[complete]` collapses the frame once it has loaded.
- **Colour:** palette with `dark:` variants only.

## Behaviour (JavaScript)

_No custom element._ Turbo does the loading (`loading="lazy"` frames and
`<turbo-stream>` elements), so this component needs Turbo, and the README says
so.

How it behaves under Turbo:
- **Turbo cache:** the snapshot holds every loaded page. The already-loaded
  frames carry `complete`, and Turbo doesn't refetch them. On Back, the
  pending last frame fetches again only when scrolled to.
- **Morph refresh:** as designed, the server re-renders page 1 plus a pending
  frame, so a refresh drops the extra pages. This is still open; see the
  recommendation under Open questions.
- **Snapshot clones:** there is no generated DOM to clean up. A cloned
  `<turbo-stream>` can't exist, because it removes itself once it has run.
- **Streamed content:** a `turbo_stream.upsert` into `rows_id` keeps working
  alongside infinite pages. A row that is streamed in and then arrives again on
  a later page is replaced, not duplicated, when rows carry ids, because
  `upsert` matches by id. Append does not, so the table path renders
  `action="upsert"` when it is available.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.infinite.more` | "Load more" |
| `unmagic.components.infinite.loading` | "Loading more…" |
| `unmagic.components.infinite.end` | "You've reached the end" |

## Specs

In `spec/unmagic/components/infinite_scroll_spec.rb`.

A normal request:
- Renders the items, then a `turbo-frame[loading=lazy]` whose `src` is
  `page_url(:next)` and whose id is `<id>_page_<next>`.
- The frame contains the fallback link.

A frame request (`build_view(turbo_frame: "messages_page_2")`):
- Renders only that frame, containing a `turbo-stream[action=append][target=messages] template` with the items and the next frame.

Last page and empty collection:
- On the last page (`next` is nil) there is no inner frame, and `.UnmagicInfinite__end` is present.
- An empty collection renders no frame.

Tables:
- `table_for paginate: :infinite` streams `<tr>`s whose ids match `row_for`.
- Without `rows_id:` it raises `ArgumentError`.
- With `defer: true` it raises `ArgumentError`.

Options:
- An unknown `tag:` raises `ArgumentError`.
- `class:` reaches the list.

## Preview

A new `/infinite` page with 200 generated rows in a table and a message-style
list. It needs a real pager that answers `previous`, `next` and `page_url`,
plus the matching `pagy_for` in `config.ru`.

Hand checks:
- Scroll to the end. Each page loads once, and the network panel shows no
  duplicate fetches.
- Keyboard-only: tab to "Load more" and press Enter.
- Back and then Forward keep the loaded pages.
- A slow response (add a `sleep`) shows the spinner, and screen readers
  announce the end marker.
- Check dark mode.

## Open questions

- **Deferred and infinite together:** should they combine? It would take a
  skeleton first page and then streams. That is more branching in `table_for`.
- **Advance the URL:** should `advance: true` push `?page=N`? Reloading would
  then show only page N.
- **Morph refresh:** should a morph refresh keep loaded pages? That would take
  `refresh="morph"` on the page frames, or rendering `1..N` on refresh.

  **Recommendation: keep them.**
  - The principles say every component survives a morph refresh, and that
    script re-applies what the reader did (`tabs.js`). Losing pages 2..N breaks
    both.
  - Losing them is also worse than it sounds. With
    `turbo_refresh_scroll :preserve`, the reader is left scrolled past the new,
    shorter end of the list. The lazy frame then refetches page 2 at once, and
    rows appear to jump.
  - `refresh="morph"` on the page frames won't help. The rows live in the list,
    not in the frames, so the morph of the list removes them whatever the
    frames do.
  - The workable route is rendering `1..N`. The helper already owns the
    request, so on a refresh it renders every loaded page's rows plus the frame
    for page N+1. N has to reach the server:
    - A small `turbo:before-fetch-request` listener, in a shared module rather
      than an element, adds `unmagic_infinite[<id>]=N` to a refresh request,
      where N comes from the last `complete` page frame.
    - That breaks this note's "no JS" line for one listener.
    - Cap N (e.g. 10 pages) so a refresh stays one bounded query.
  - If that is judged too much for v1, keep the drop. But document it, and make
    the helper scroll the list back to its top on `turbo:morph`, so the reader
    lands on page 1 rather than past the end.
