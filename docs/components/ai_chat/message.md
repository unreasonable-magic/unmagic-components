# `ai_chat_message`

> Status: draft
> Tier: 1 (no JS of its own)
> Relates to: [transcript](transcript.md), [streaming_markdown](streaming_markdown.md), [action_bar](action_bar.md), [branch_picker](branch_picker.md), `<unmagic-optimistic>`

## Purpose

One turn in a transcript. A user turn is a bubble of plain text; an assistant
turn is unbubbled prose. The asymmetry is the component's main opinion and all
three applications arrived at it independently: a question is a remark and an
answer is a document — headings, lists, tables, a paragraph that runs on — and a
box drawn around a page of prose only makes it narrower.

For the turns themselves. A tool call is [tool_call](tool_call.md), a question
is [request](request.md), and a failure is [failure](failure.md), even though
the model considers all three to be messages.

## API

```erb
<%# A user turn %>
<%= ai_chat_message role: :user, id: dom_id(message) do %><%= message.content %><% end %>

<%# An assistant turn: already-rendered, already-sanitised HTML %>
<%= ai_chat_message role: :assistant, id: dom_id(message), streaming: message.pending? do |message_| %>
  <% message_.reasoning { Markdown.render(record.thinking_text) } %>
  <%= Markdown.render(record.content) %>
  <% message_.actions do %><%= ai_chat_action_bar … %><% end %>
<% end %>

<%# The composer's optimistic template %>
<%= ai_chat_message role: :user, optimistic: { id: "message[client_id]", text: "message[content]" } %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `role:` | `:user`, `:assistant` | required | Validated; raises `ArgumentError` |
| `id:` | string | `nil` | The record's element id, for `upsert` to reconcile against |
| `streaming:` | boolean | `false` | Wraps the body in `<unmagic-streaming-markdown>` |
| `final:` | boolean | `false` | A settled turn that must refuse a late flush |
| `optimistic:` | hash | `nil` | `{ id:, text: }` naming form fields; see below |

Builder parts, each recording and returning `nil`:

- `message.reasoning { }` — a collapsed "thought process" disclosure above the
  body. See [reasoning](reasoning.md).
- `message.actions { }` — the action bar under the body.
- `message.branches { }` — the branch picker beside the actions.
- `message.attachments { }` — above a user turn's bubble, which is the order it
  happened in and the order the model was given it in.

There is no `role: :tool`. A tool result is not a turn to read — it feeds the
model — so the host renders the hidden anchor that holds its place in the order
itself, in one line, rather than the gem shipping a helper that draws nothing.

`optimistic:` renders the same markup with the id and the text left for
`<unmagic-optimistic>` to fill from the named fields, and the bubble dimmed until
the server confirms it. One markup, two states, so a confirmed bubble and the
bubble that stood in for it can never read differently — this is worth the option
and all three applications that do it hand-rolled the duplication.

An empty assistant turn with `streaming: false` renders `hidden`: a settled turn
that only made tool calls has nothing to say, but stays in the DOM so a broadcast
can key on its id.

## Markup

```html
<!-- user -->
<div id="message_1" class="UnmagicAIChatMessage UnmagicAIChatMessage--user">
  <div class="UnmagicAIChatMessage__bubble">How many are left?</div>
</div>

<!-- assistant -->
<div id="message_2" class="UnmagicAIChatMessage UnmagicAIChatMessage--assistant">
  <details class="UnmagicAIChatReasoning">…</details>
  <unmagic-streaming-markdown id="message_2_content" class="UnmagicProse">…</unmagic-streaming-markdown>
  <div class="UnmagicAIChatMessage__actions">…</div>
</div>
```

The body element's id is the record's id with `_content` appended, because the
streaming flush targets the body while the upsert targets the whole turn. That
convention is hooops's and it is load-bearing; the note names it so the host
doesn't have to guess.

## Accessibility

- Turns are ordinary content in the transcript's `role="log"`. Nothing here is a
  live region of its own.
- The role is conveyed by text, not by alignment or colour: each turn opens with
  a visually hidden "You said" / "Assistant said", which is the only way a
  non-visual reader can tell a bubble from prose.
- An assistant body that is streaming carries `aria-busy="true"` until it
  settles, so a screen reader announces the finished reply once rather than
  every flush.
- `UnmagicVisuallyHidden` for the role labels.
- The action bar and branch picker are real buttons in the tab order, after the
  body.

## Styling

CSS section: **AI chat messages**.

- `.UnmagicAIChatMessage`, `--user`, `--assistant`
- `.UnmagicAIChatMessage__bubble`, `__actions`, `__attachments`

A user bubble: `max-w-[85%]`, `rounded-2xl rounded-br-sm`, `px-4 py-2.5`,
`text-sm`, `whitespace-pre-wrap`, and `bg-neutral-900 text-white` with
`dark:bg-neutral-100 dark:text-neutral-900`. The assistant turn has no surface
of its own and inherits the page.

`whitespace-pre-wrap` on the bubble is deliberate and worth a comment in the CSS:
a user turn is typed into a box, never Markdown, and the newlines they typed are
the only formatting they have.

State comes from attributes: `[data-optimistic]` dims to `opacity-60`,
`[aria-busy="true"]` is what the action bar hides behind, so no state classes.

Motion: none. A turn appearing is not an animation; it is content.

## Behaviour (JavaScript)

None of its own. It composes `<unmagic-streaming-markdown>` when `streaming:`,
and `<unmagic-optimistic>` reads the template it renders when `optimistic:`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.message.user` | "You said" |
| `unmagic.components.ai_chat.message.assistant` | "Assistant said" |

## Specs

`spec/unmagic/components/ai_chat_message_spec.rb`:

- Each role's classes, and the visually hidden label.
- `id:` on the root, and `#{id}_content` on the body.
- `streaming: true` wraps in `<unmagic-streaming-markdown>`; `final: true` adds
  the `final` attribute; `false` renders a plain element.
- An empty assistant turn renders `hidden`; an empty user turn does not.
- `optimistic:` emits `data-optimistic-id` and `data-optimistic-text` with the
  given field names, adds `data-optimistic`, and omits the `id`.
- Each builder part renders in its documented position, and an unused part
  renders nothing.
- `ArgumentError` for an unknown role.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A transcript showing: a user turn, a long assistant turn with
headings and a list, a streaming turn, a settled empty turn, an optimistic
bubble, and a turn with attachments, reasoning, actions and branches all at once.

By hand: dark theme; a very long unbroken token in a user bubble (it must wrap,
not scroll the page); keyboard reach to the actions.

## Open questions

- Should `role:` admit `:system`? None of the three renders standing instructions
  in the transcript, and both that reviewed it concluded they do not belong
  there. Proposed: no, until something asks for it.
