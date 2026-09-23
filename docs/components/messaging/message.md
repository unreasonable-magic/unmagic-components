# `message`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `ai_chat_message` (now a subclass), `avatar`,
> `local_time_tag`, `message_actions`, `message_reactions`, `message_attachments`

## Purpose

One message in a conversation: who sent it, when, what it says, what came with
it and what happened to it. Three looks: a `:bubble` for a chat between people
or with an assistant, a `:row` for a channel or a thread, and an `:email` for a
letter with a header and a body.

For a message. A tool call, a permission request or a plan step in an agent's
transcript is its `ai_chat_*` component, and an event in a history is a
`timeline` event.

## API

```erb
<%# The common case: a bubble from someone else %>
<%= message "Are we still on for Friday?", author: "Ana Silva", time: message.sent_at %>

<%# A bubble of your own, with its status %>
<%= message own: true, time: message.sent_at do |m| %>
  <% m.status :read, at: message.read_at %>
  Yes, 2pm at the usual place.
<% end %>

<%# A row in a channel, with everything %>
<%= message variant: :row, id: dom_id(message), author: message.author.name, avatar: true, time: message.sent_at,
            edited: message.edited? do |m| %>
  <% m.quote "Can someone review the release notes?", author: "Ben Reyes", href: message_path(message.parent) %>
  <% m.attachments { |files| files.file "notes.md", size: 1_240, url: "…" } %>
  <% m.reactions { |r| r.reaction "👍", count: 2, url: react_path(message) } %>
  <% m.footer { link_to "3 replies", thread_path(message) } %>
  <% m.actions { |bar| bar.action "Reply", reply_path(message), icon: :reply } %>
  <%= Markdown.render(message.body) %>
<% end %>

<%# An email, collapsed until opened %>
<%= message variant: :email, author: "Ana Silva", avatar: true, time: mail.sent_at, collapsible: true, open: false do |m| %>
  <% m.meta "to Ben Reyes, Chloe Park" %>
  <% m.actions(reveal: :always) { |bar| bar.control { link_to "Reply", reply_path(mail), class: button_classes(size: :small) } } %>
  <%= mail.html_body %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `variant:` | `:bubble`, `:row`, `:email` | `:bubble` | Validated; raises `ArgumentError` |
| `own:` | boolean | `false` | Sent by the viewer. A bubble sits on the right on the dark surface; on a row or an email it only adds the modifier class |
| `author:` | string | `nil` | The sender's name, in the header. Pass it on a continued message too: it stays in the DOM for screen readers |
| `avatar:` | `true`, a name, or a Hash of `avatar` options | `nil` | `true` draws the author's initials and needs `author:` (raises otherwise); a Hash takes `name:`, `src:`, … Sizes: `:small` for a bubble, `:medium` for a row or an email |
| `time:` | Time, Date, String, `nil` | `nil` | A Time goes through `local_time_tag`; a String prints as it is |
| `time_format:` | a `local_time_tag` format | `:time`, or `:medium` for `:email` | Passed through |
| `continued:` | boolean | `false` | Same sender as the message above, moments later: the name and avatar are hidden (the avatar's column is kept), the gap tightens, bubble corners join |
| `edited:` | boolean | `false` | "Edited" in the footer |
| `collapsible:` | boolean | `false` | The header becomes a `<details>` summary with a snippet of the body. Meant for `:email` |
| `open:` | boolean | `true` | Whether a collapsible message starts open |
| `id:` | string | `nil` | On the root, for broadcasts and for the actions' `aria-controls` |

Builder parts, each recording and returning `nil`:

- `m.meta(content)` — a line under the author: "to Ben, Chloe", "via SMS", a
  badge.
- `m.quote(content = nil, author: nil, href: nil, &block)` — the message this
  one replies to, above the body. `href:` links the author to it and sets
  `cite`.
- `m.attachments { }` — after the body. A block that takes an argument gets a
  `message_attachments` builder (`{ |files| files.file … }`); one that doesn't
  is captured as markup.
- `m.reactions { }` — after the attachments. Likewise: `{ |r| r.reaction … }`
  builds `message_reactions`, or the block is markup.
- `m.status(state, at: nil)` — `:sending`, `:sent`, `:delivered`, `:read` or
  `:failed`, validated, in the footer; `at:` adds the time ("Read 2:14 pm").
- `m.footer { }` — the host's own footer content, beside edited and status: a
  "3 replies" link, a "View thread".
- `m.actions(**options) { }` — the controls. `{ |bar| bar.action … }` builds
  `message_actions for: id` with the options given (`reveal:`), raising when the
  message has no `id:`; a block without an argument is markup. Placed by the
  variant: beside a bubble, floating over a row, under an email.

The body is the block, or the positional argument when the block only records
parts (`message "Will do", own: true do |m| m.status :read end`). A bubble keeps the line
breaks that were typed (`whitespace-pre-wrap`) and trims a block's surrounding
whitespace; a row's or an email's body is prose (`UnmagicProse`) and takes the
host's rendered, sanitised HTML.

Other options go on the root. Blank content renders an empty body; a message
that says nothing but attaches something is still a message.

## Markup

```html
<article id="message_1" class="UnmagicMessage UnmagicMessage--row" data-status="read">
  <div class="UnmagicMessage__avatar"><span class="UnmagicAvatar …" aria-hidden="true">…</span></div>
  <div class="UnmagicMessage__main">
    <div class="UnmagicMessage__header">
      <span class="UnmagicMessage__author">Ana Silva</span>
      <span class="UnmagicMessage__meta">to Ben Reyes</span>
      <unmagic-time class="UnmagicMessage__time" …><time>2:14 pm</time></unmagic-time>
    </div>
    <blockquote class="UnmagicMessage__quote" cite="/messages/7">
      <a class="UnmagicMessage__quoteAuthor" href="/messages/7">Ben Reyes</a>
      <span class="UnmagicMessage__quoteText">Can someone review the release notes?</span>
    </blockquote>
    <div class="UnmagicMessage__body UnmagicProse">…</div>
    <div class="UnmagicMessage__attachments">…</div>
    <div class="UnmagicMessage__reactions">…</div>
    <div class="UnmagicMessage__footer">
      <span class="UnmagicMessage__edited">Edited</span>
      <span class="UnmagicMessage__status"><svg class="UnmagicIcon" aria-hidden="true">…</svg> Read <unmagic-time …>…</unmagic-time></span>
      <span class="UnmagicMessage__extra">…host footer…</span>
    </div>
  </div>
  <div class="UnmagicMessage__actions">…</div>
</article>
```

The same elements, in the same order, for every variant; only the variant class
changes, and the CSS lays them out. Parts that weren't given aren't rendered.
An own message with no author opens its header with a visually hidden "You", so
a screen reader can tell whose bubble it is. State is on the root:
`data-status` (the footer only shows the word and glyph) and `data-optimistic`
(what `<unmagic-optimistic>` marks a drawn-ahead message with).

A collapsible message keeps the `<article>` root and wraps its inside in a
`<details>`. The summary is phrasing content only, so the avatar and header
become `<span>`s there, and it is the one form where `__header` sits outside
`__main`:

```html
<article class="UnmagicMessage UnmagicMessage--email">
  <details open>
    <summary class="UnmagicMessage__summary">
      <span class="UnmagicMessage__avatar">…</span>
      <span class="UnmagicMessage__header">…author, meta, time…</span>
      <span class="UnmagicMessage__snippet" aria-hidden="true">Thanks both. I've booked the room for…</span>
    </summary>
    <div class="UnmagicMessage__main">…quote, body, attachments, reactions, footer…</div>
    <div class="UnmagicMessage__actions">…</div>
  </details>
</article>
```

The snippet is the body's text, stripped and truncated to 120 characters, hidden
while open and `aria-hidden` always, so the summary's name is the header and
doesn't change with the state.

`<article>` because a message is a self-contained piece a reader can take on its
own, which is what the element (and the ARIA role) means; `<details>` because
collapsing is disclosure, and the platform's disclosure works without script.

## Subclass hooks

`ai_chat_message` is `AIChat::Message < Messaging::Message`. The generic class
renders through protected methods the subclass overrides, and nothing else:

| Hook | Generic | AI chat |
|---|---|---|
| `root_attributes` | `id`, `data-status` | omits the id when optimistic, adds `hidden` for a settled empty assistant turn, `data-optimistic` and `data-optimistic-id` |
| `speaker_label` | "You" when own with no author | "You said" / "Assistant said", always |
| `before_body` | nothing | the reasoning disclosure |
| `body_element(content)` | a `div.UnmagicMessage__body` | for an assistant turn with an id, `<unmagic-streaming-markdown id="#{id}_content" class="UnmagicMessage__body UnmagicProse">`, with the thinking spinner while streaming; for a user turn, the bubble with `data-optimistic-text` when optimistic |
| `footer` | edited, status, host footer | `UnmagicAIChatMessage__footer` with the branch picker and the action bar |
| `actions` | `UnmagicMessage__actions` | none; the actions are in the footer, static under the prose |

A user turn is `variant: :bubble, own: true`; an assistant turn is
`variant: :row` with no avatar. The root carries `UnmagicMessage`,
`UnmagicMessage--bubble`/`--row`, and `UnmagicAIChatMessage`,
`UnmagicAIChatMessage--user`/`--assistant` for the AI-only rules.

The rename this brings: `UnmagicAIChatMessage__bubble` and
`UnmagicAIChatMessage__body` both become `UnmagicMessage__body`, and
`UnmagicAIChatMessage__attachments` becomes `UnmagicMessage__attachments`. It
touches `engine.css` (the AI chat messages and action bars sections),
`ai_chat_transcript_spec.rb`, `ai_chat_composer_spec.rb`, the browser's
`demos_controller.rb` (which builds the stopped body by hand), and the AI chat
notes. The CHANGELOG lists it.

## Accessibility

- Messages are articles. In a live thread they are ordinary content in the
  thread's `role="log"`; nothing here is a live region of its own.
- Who said it is text, not alignment or colour. The author's name is in the
  header; an own message without one opens with a visually hidden "You"; a
  continued message keeps its author in the DOM, visually hidden, so a reader
  moving through the log still hears the speaker.
- The time is a `local_time_tag`, so it reads in the viewer's zone and locale.
- Status is a word with a glyph ("Read", "Not delivered"), never a colour alone.
- A collapsed email is a native `<details>`: Enter and Space toggle it, and its
  summary is the header, so the name, meta and time are what a reader hears
  before opening it.
- The actions are `message_actions`: a toolbar in the tab order after the body,
  never hidden from the keyboard. The reactions are `message_reactions`:
  buttons with `aria-pressed`.
- Decorative avatars are `aria-hidden` (the name is written beside them).

## Styling

CSS section: **Messages**.

- `.UnmagicMessage`, `--bubble`, `--row`, `--email`, `--own`, `--continued`
- `__avatar`, `__main`, `__header`, `__author`, `__meta`, `__time`, `__quote`,
  `__quoteAuthor`, `__quoteText`, `__body`, `__attachments`, `__reactions`,
  `__footer`, `__edited`, `__status`, `__extra`, `__actions`, `__summary`,
  `__snippet`

**Bubble.** The root is `flex flex-wrap items-end gap-2`; `--own` is
`flex-row-reverse`, which puts the bubble on the right and the actions (and an
own avatar) on its open side, in CSS only: the DOM order never changes.
`__main` is a column, `max-w-[85%]`, `items-start` (`--own`: `items-end`);
`__attachments` inside it is `order: -1`, above the bubble, because attachments
are sent before the words that go with them (the order `ai_chat_message` always
used). The body is the bubble: `rounded-2xl rounded-bl-sm px-4 py-2.5 text-sm
leading-relaxed whitespace-pre-wrap`, `overflow-wrap: anywhere`; another's
bubble is `bg-neutral-100 text-neutral-900 dark:bg-neutral-800
dark:text-neutral-100` and an own bubble `rounded-br-sm bg-neutral-900
text-white dark:bg-neutral-100 dark:text-neutral-900`, the surfaces
`ai_chat_message` already uses. A `--continued` bubble squares its top corner
on the joined side (`rounded-tl-sm` / `rounded-tr-sm`), hides its header
(visually only) and draws no avatar in a column it keeps.

**Row.** `grid grid-cols-[auto_minmax(0,1fr)] gap-x-3`, `relative`. Placement is
explicit, because auto-placement would put a lone `__main` in the `auto`
column: `__avatar` is column 1; `__main` is column 2, or `1 / -1` when the root
has no avatar (`:not(:has(> .UnmagicMessage__avatar))`). The header is `flex
items-baseline gap-2`: author `font-semibold text-sm`, time `text-xs
text-neutral-500`. The body is `UnmagicProse`. The actions float: `absolute
-top-3 right-2` in a `rounded-lg border border-neutral-200 bg-white p-0.5
shadow-xs` pill (`dark:` pairs). A `--continued` row's header holds only its
time, absolutely positioned in the avatar column (`left-0 top-0.5
text-[0.625rem]`), visible on hover and on `:focus-within`, and always under
`hover: none`.

**Email.** A card: `rounded-xl border border-neutral-200 bg-white p-4
dark:border-neutral-800 dark:bg-neutral-900`. The avatar sits in the card's
corner (`absolute`) and the header clears it with `pl-11`; the body runs the
full width under both. The header is `flex flex-wrap`: the author grows, the
time is `ml-auto whitespace-nowrap`, and the meta line is `order-1 basis-full`
under the author, so the time drops under the author when there's no room. The body is `UnmagicProse`
with `mt-3`. The actions sit under the body, static, `mt-4`, and a
`[data-reveal="hover"]` bar inside an email is always shown: there is nothing to
hover for. A collapsible email's `summary` is `cursor-pointer list-none` with no
marker and the shared focus ring; the snippet is `truncate text-sm
text-neutral-500` and `details[open] > summary .UnmagicMessage__snippet` is
hidden.

**Actions, the six cases.**

| | pointer with hover | `hover: none` |
|---|---|---|
| bubble | inline beside the bubble, shown on hover/focus | `basis-full`, under the bubble on its side |
| row | floating pill top-right, shown on hover/focus | static, `grid-column: 2` (or `1 / -1` with no avatar), under the body |
| email | static under the body, always shown | the same |

**Shared.** The quote: `border-l-2 border-neutral-300 pl-3 text-sm
text-neutral-600 dark:border-neutral-600 dark:text-neutral-400`, author
`font-medium`. The footer: `flex flex-wrap items-center gap-2 text-xs
text-neutral-500`. The status glyph is `size-3.5`; `[data-status="read"]
.UnmagicMessage__status` is `text-blue-600 dark:text-blue-400`, `failed` is
`text-red-600 dark:text-red-400`, and `[data-status="sending"]` and
`[data-optimistic]` dim the body (`> .UnmagicMessage__main >
.UnmagicMessage__body`) to `opacity-60`.

State comes from attributes on the root: `[data-status]`, `[data-optimistic]`,
and `details[open]` inside. `--own` and `--continued` are structure, not state.

Motion: none. A message appearing is content, not an animation.

## Small screens

- A bubble is at most 85% of the thread; a long token wraps
  (`overflow-wrap: anywhere`).
- Under `hover: none` the actions can't be summoned, so they are placed
  statically as the table above says.
- The email header wraps: the time drops under the author when there's no room.
- Controls are `UnmagicButton`s, which are 44px under a coarse pointer.

## Behaviour (JavaScript)

_None: CSS and markup only._ It composes `<unmagic-time>` for the time, and
`message_actions` brings `<unmagic-toolbar>`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.message.you` | "You" |
| `unmagic.components.message.edited` | "Edited" |
| `unmagic.components.message.status.sending` | "Sending" |
| `unmagic.components.message.status.sent` | "Sent" |
| `unmagic.components.message.status.delivered` | "Delivered" |
| `unmagic.components.message.status.read` | "Read" |
| `unmagic.components.message.status.failed` | "Not delivered" |

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- Each variant's root class; `own:` and `continued:` modifiers; `id:` on the
  root; passthrough `class:` and attributes.
- The header: author, meta, and the time as `<unmagic-time>` with the format;
  a string time as text; no header when there's nothing for it.
- `avatar: true` draws the author's initials, `aria-hidden`, at the variant's
  size; a Hash passes through; `continued:` omits the avatar but keeps its
  column; `avatar: true` without `author:` raises.
- A bubble body keeps text escaped and trims a block; a row body carries
  `UnmagicProse`.
- Parts render in the documented order and an unused part renders nothing;
  `m.actions`, `m.reactions` and `m.attachments` yield a builder to a block with
  an argument and capture one without; `m.actions` with a builder needs `id:`.
- `status` renders the word and glyph in the footer and `data-status` on the
  root; `at:` adds a time; an unknown state raises.
- An own message with no author has the visually hidden "You".
- `collapsible:` renders the `<details>` inside the article with the header in
  `<summary>` as spans, the snippet from the body's text, and `open` following
  `open:`.
- `ArgumentError` for an unknown variant.

## Preview

Page: `message`. Examples: the three variants side by side; own and other;
continued runs; statuses; quotes, attachments, reactions and actions on one
message; a collapsed and an open email.

By hand: dark theme; a phone width with touch (actions shown without hover);
Tab into a row's actions and see them appear; open and close a collapsed email
from the keyboard.

## As built

- The body is the block, or the content when the block only records parts.
- A row's `__actions` wrapper (the floating pill) hides and shows with the bar
  inside it (`:has(> .UnmagicMessageActions[data-reveal="hover"])`), or its
  surface would stand empty.

## Open questions

- Linked authors and rich bodies: see the family README.
