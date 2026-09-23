# Messaging component design notes

Components for showing people talking to each other, or to a machine: a
conversation of messages, with who said it, when, what they attached, how
others reacted, and what can be done to it. One family renders an iMessage-style
chat, a Slack-style channel or thread, an email back-and-forth and an AI chat.

One note per component, written and reviewed **before** the component is built.
Each follows [`../_template.md`](../_template.md) and is held to the
[design principles](../../design-principles.md).

## Where this family came from

The [AI chat](../ai_chat/README.md) family shipped with a message component and
an action bar, and both turned out to be about messages rather than about
agents: a user's bubble, an unbubbled reply, a row of icon controls that shows
on hover. Meanwhile the applications this gem serves also render conversations
between people: a recruiter's email thread, a team's channel, a support inbox.
Each was drawing its own bubbles.

So the generic parts move out of `ai_chat` into this family, and `ai_chat_message`
becomes a specialisation of `message` (it adds streaming, the thinking spinner,
the optimistic template and reasoning) rather than a second implementation.
`ai_chat_action_bar` is now `message_actions` under its old name, and
`ai_chat_attachments` is `message_attachments`.

The catalogue is measured against Untitled UI's messaging set (message bubbles
with avatar, name and time; sent, read and failed status; reactions; quoted
replies; file, image and audio attachments; link previews; typing indicators; a
date-grouped list). It is used as a list of what a messaging UI needs; none of
its markup, classes or code is used here.

## Anatomy

| Untitled UI | Here | Note |
|---|---|---|
| Message list, grouped by date | `message_thread` + `message_separator` | [thread](thread.md), [separator](separator.md) |
| Message (sent / received, avatar, name, time) | `message` | [message](message.md) |
| Message status (sent, read, failed) | `message.status` | [message](message.md) |
| Reactions | `message_reactions` | [reactions](reactions.md) |
| Reply (quoted) | `message.quote` | [message](message.md) |
| File attachments | `message_attachments` | [attachments](attachments.md) |
| Image, audio, link preview | — | the body is the host's markup; see open questions |
| Typing indicator | `message_typing` | [typing](typing.md) |
| Composer | — | `ai_chat_composer`, or the host's own form |
| — | `message_actions` | [actions](actions.md) |
| — | `variant: :email` with `collapsible:` | [message](message.md) |

## The notes

| Note | Tier | Status |
|---|---|---|
| [thread](thread.md) | 1 | built |
| [message](message.md) | 1 | built |
| [actions](actions.md) | 2 (reuses `<unmagic-toolbar>`) | built |
| [attachments](attachments.md) | 1 | built |
| [reactions](reactions.md) | 1 | built |
| [separator](separator.md) | 1 | built |
| [typing](typing.md) | 1 | built |

## Decisions

### Decided

- **The namespace is `message`.** Helpers are `message`, `message_thread`,
  `message_actions`, `message_reactions`, `message_separator` and
  `message_typing`; classes live in `Unmagic::Components::Messaging`; CSS blocks
  are `UnmagicMessage*`. `chat_*` was rejected because email isn't chat and
  because toybox already has four `chat_*` helpers. The root is `message_thread`
  rather than a bare word, since `thread` on its own reads as Ruby's.

- **The look is per message, not per thread.** `message` takes
  `variant: :bubble | :row | :email`. A thread is only a container with the
  spacing and the live-region role, so a thread can mix variants: an AI chat is a
  bubble followed by a row, which is exactly the asymmetry `ai_chat_message`
  argued for. A thread that set the variant for its messages would need every
  message to know its thread, and a partial rendered by a broadcast doesn't.

- **The server decides grouping.** Every client tightens consecutive messages
  from the same sender (one avatar, one name, joined bubbles). The gem draws
  that when the host says `continued: true`; it doesn't compare neighbours,
  because a message streamed in on its own has no neighbour to compare with.
  The host has the timestamps and the sender ids; it's one line of Ruby there.

- **One markup for every variant.** Avatar, header (author, meta, time), quote,
  body, attachments, reactions, footer (edited, status), actions: the same
  elements in the same order, laid out differently by the variant's CSS. A host
  that overrides one class overrides it everywhere, and a message that changes
  variant (a channel row opened in a bubble-style thread panel) keeps its
  structure.

- **`ai_chat_message` is a subclass of `message`.** It keeps its API
  (`role:`, `streaming:`, `final:`, `optimistic:`, `turn.reasoning`,
  `turn.branches`) and its own extras (`UnmagicAIChatMessage__thinking`, its
  footer with the branch picker) but renders the generic root, header and body,
  so the two can never drift apart. Its root carries both `UnmagicMessage` and
  `UnmagicAIChatMessage` classes. `UnmagicAIChatMessage__bubble` becomes
  `UnmagicMessage__body`; the CHANGELOG says so.

- **`ai_chat_action_bar` is `message_actions`, and `ai_chat_attachments` is
  `message_attachments`.** Same classes, same markup; the old helper names stay
  as aliases. The CSS blocks are now `UnmagicMessageActions` and
  `UnmagicMessageAttachments`. The action bar's label key moves to
  `unmagic.components.message.actions.label`, falling back to the old
  `unmagic.components.ai_chat.action_bar.label` so a host's translation still
  applies.

- **Parts yield builders.** `m.actions { |bar| … }`, `m.reactions { |r| … }` and
  `m.attachments { |files| … }` build the matching component in place when the
  block takes an argument (the actions bar gets the message's own `id:`), and
  capture markup when it doesn't. Three levels of nesting and a repeated id were
  the first thing the review flagged.

- **The browser gets a "Messaging" group,** between "Data display" and "AI chat",
  with one page per helper as the AI chat family has. The `ai_chat_action_bar`
  and `ai_chat_attachments` pages retire in favour of the new ones.

- **Reactions are forms.** A reaction pill is a `button_to` with `aria-pressed`,
  so toggling one is a POST the host already knows how to handle, with no
  script. The gem ships no emoji picker (see the emoji picker decision in the
  design principles); `reactions.add` renders the button and the host wires it
  to whatever picker it has, a native `popover` in the examples.

- **Status is words and an icon, never a colour alone.** "Sent", "Delivered",
  "Read", "Not delivered" with a glyph each; only read is coloured (blue,
  information) and only failed is red (bad).

- **No new JavaScript.** The action bar reuses `<unmagic-toolbar>`; a collapsed
  email is a `<details>`; the typing indicator is a CSS animation; reactions are
  forms; times are `local_time_tag`.

- **The typing indicator is not a live region of its own.** Its home is a live
  thread, whose log announces its arrival; a nested `role="status"` would say it
  twice. Outside a live thread the host passes `role: "status"`.

### Still open

1. **Rich bodies.** Untitled UI has image messages, audio messages and link
   previews. The body takes any markup, so an `image_tag` or an `<audio>` already
   works; a link preview card is a candidate for a later `message.preview` part
   once an application needs one.
2. **Linked authors.** `author:` is text. Slack links the name to a profile;
   a later `author_href:` (or an `author { }` part) can add it without changing
   the markup.
3. **Sticky date separators.** iMessage and Slack pin the current date to the
   top while scrolling. A `sticky: true` on `message_separator` is cheap CSS but
   needs a scroll container to be sticky in, which is the host's; deferred until
   a thread owns its scroller.
