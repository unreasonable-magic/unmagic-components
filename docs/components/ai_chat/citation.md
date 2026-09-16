# `ai_chat_citation`

> Status: built
> Tier: 1 (no JS)
> Relates to: [message](message.md), [proposal](proposal.md)

## As built

Where the build differs from this note:

- `cite.avatar` with no block renders the gem's own `avatar` for `who`, which was built for this.

## Purpose

An embedded reference to something the agent is quoting — a message, a document,
a row — rendered from the record rather than from the model's paraphrase of it.
Set apart from the model's own prose so it reads as a citation.

The point is stated best by kp2, which built it: the agent emits a token naming
the record, and the application renders the original from the database, so the
quote is the real wording. A model asked to reproduce a quotation will
approximate it, and an approximated quotation attributed to a real person is a
small forgery. This component exists so the quoting is never the model's job.

For quoting a record the application holds. Not for a link to a source — that is
just a link — and not for the agent's own prose.

## API

```erb
<%= ai_chat_citation do |c| %>
  <% c.avatar { sender_avatar(message) } %>
  <% c.who message.sender_name %>
  <% c.when message.received_at, url: message_path(message) %>
  <% c.quote message.body %>
<% end %>

<%# A source list under a reply %>
<%= ai_chat_citation compact: true do |c| %>
  <% c.who "Handbook · Leave policy" %>
  <% c.quote "Four weeks, accruing monthly." %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `compact:` | boolean | `false` | One line, for a list of sources under a reply |

Builder parts: `c.avatar { }`, `c.who(text)`, `c.when(time, url:)`,
`c.quote(text)`.

- `c.quote` takes plain text and renders it with newlines preserved, escaped.
  Model output cannot inject markup through it, and neither can the quoted
  record — this is the component's security boundary and the class comment says
  so.
- `c.when` renders through the gem's `local_time_tag`, so a citation's timestamp
  follows the reader's zone like every other time in the gem.
- With no parts it renders nothing.

## Markup

```html
<figure class="UnmagicAIChatCitation">
  <div class="UnmagicAIChatCitation__avatar">…</div>
  <div>
    <figcaption class="UnmagicAIChatCitation__caption">
      <span class="UnmagicAIChatCitation__who">Ana</span>
      <a href="…"><unmagic-time datetime="…">2 Mar 2026, 4:12 pm</unmagic-time></a>
    </figcaption>
    <blockquote class="UnmagicAIChatCitation__quote">…</blockquote>
  </div>
</figure>
```

`<figure>`, `<figcaption>` and `<blockquote>` — the semantics already exist for
exactly this and nothing needed inventing.

## Accessibility

- Real `<blockquote>` and `<figcaption>`, so the attribution is associated with
  the quotation rather than merely adjacent to it.
- The avatar is `aria-hidden` when `who` is present; the name is the
  attribution.
- `not-prose` where it sits inside `UnmagicProse`, as [proposal](proposal.md)
  does.
- A `cite` attribute on the `<blockquote>` when `when` was given a url.

## Styling

CSS section: **AI chat citations**.

- `.UnmagicAIChatCitation`, `--compact`, `__avatar`, `__caption`, `__who`,
  `__quote`

A left rule is what sets it apart from the prose around it:
`border-l-[3px] border-blue-300 bg-neutral-50 px-2 py-1 rounded-md`, with
`dark:border-blue-800 dark:bg-neutral-950`. Blue, matching the info tone the
proposal glyph uses, so the two quiet inline cards agree.

`whitespace-pre-wrap` on the quote: a quoted message keeps its line breaks.

`--compact` drops the avatar and puts the caption and quote on one line with a
truncating quote.

## Behaviour (JavaScript)

None of its own; `local_time_tag` brings `<unmagic-time>`.

## I18n

None — every word is the quoted record's.

## Specs

`spec/unmagic/components/ai_chat_citation_spec.rb`:

- figure/figcaption/blockquote structure.
- The quote escapes markup and preserves newlines.
- `when` renders a `<unmagic-time>`, and wraps it in a link when given a url.
- `cite` on the blockquote only when a url was given.
- `compact:` classes, and no avatar.
- No parts renders nothing.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A full citation with an avatar; a compact one; one whose quote
contains `<script>` and newlines; and three in a row under a reply.

By hand: dark theme; the escaped markup shows as text.

## Open questions

- Should there be a numbered-footnote variant, the way a research assistant cites
  inline? Proposed: not this round. It needs a numbering scheme spanning a whole
  reply, which is a different component (`ai_chat_sources`) and no application here
  has asked for it.
