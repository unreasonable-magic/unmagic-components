# AI chat component design notes

The components for rendering an agent's work: a transcript of turns, the tools it
reached for, the plan it is following, the questions it stopped to ask, and the
box a person answers in.

One note per component, written and reviewed **before** the component is built.
Each follows [`../_template.md`](../_template.md) and is held to the
[design principles](../../design-principles.md).

## Where this round came from

Three applications on this machine each grew their own agent UI, independently,
and arrived at nearly the same shape:

- **hooops** (`app/views/assistant/`) — the streamed reveal. Its
  `streaming_markdown.js` decouples reveal cadence from arrival and reconciles
  block by block; nothing else here comes close to it. Also elicitation forms
  built from a JSON schema, and a plan + workspace sidebar.
- **kp2** (`app/views/assistant/`) — inline generative cards. A `proposal`
  layout (approve / dismiss, settling into a quiet decided state) reused by four
  different domain objects, citation blocks quoting real records, suggestion
  chips, and a slash-command menu.
- **toybox** (`app/views/chats/`) — the most evolved transcript. A hairline
  timeline joining consecutive tool calls, a glyph that says what a call was
  *about* rather than a column of identical ticks, live elapsed clocks,
  partial-failure counts, permission gates, multi-choice question cards, and
  sub-agent delegation.

Where all three converged, the design is settled and the note only has to write
it down. Where one of them invented something the others lack, the note has to
argue for it. The notes say which case they are in.

Two files are the sharpest evidence for extracting any of this at all:
`auto_scroll_controller.js` and `optimistic_controller.js` exist in both hooops
and toybox as the same logic, already drifted apart (29 and 26 differing lines).
The gem already owns the other half of that contract — `upsert.js` and
`<uuid-input>` — so those two are less new components than a missing third of
something the gem half-ships today.

The catalogue is also measured against [assistant-ui](https://www.assistant-ui.com),
which is the reference for this kind of UI on the React side. Its primitive
vocabulary is a useful checklist; none of its markup or code is used here.

## Anatomy

| assistant-ui | Here | Note |
|---|---|---|
| `ThreadPrimitive.Root` / `.Viewport` | `ai_chat` | [transcript](transcript.md) |
| `ThreadPrimitive.Messages` | the host's own entry partials | [transcript](transcript.md) |
| `Thread.Welcome` + `Suggestions` | `ai_chat_welcome` | [welcome](welcome.md) |
| `ThreadPrimitive.ScrollToBottom` | `ai_chat`'s scroll-to-latest | [transcript](transcript.md) |
| `MessagePrimitive` | `ai_chat_message` | [message](message.md) |
| `MarkdownText` | host-rendered HTML in `<unmagic-streaming-markdown>` | [streaming_markdown](streaming_markdown.md) |
| `ComposerPrimitive` | `ai_chat_composer` | [composer](composer.md) |
| `ActionBarPrimitive` | `ai_chat_action_bar` | [action_bar](action_bar.md) |
| `BranchPickerPrimitive` | `ai_chat_branch_picker` | [branch_picker](branch_picker.md) |
| Tool UI / `ToolFallback` | `ai_chat_tool_call` | [tool_call](tool_call.md) |
| `ToolGroup` | `ai_chat_tool_call`'s timeline rail | [tool_call](tool_call.md) |
| `ReasoningGroup` | `ai_chat_reasoning` | [reasoning](reasoning.md) |
| `Attachment` | `ai_chat_attachments` | [attachments](attachments.md) |
| `ThreadList` | — | `table_for` already renders an index of chats |
| — | `ai_chat_permission` | [permission](permission.md) |
| — | `ai_chat_request` | [request](request.md) |
| — | `ai_chat_proposal` | [proposal](proposal.md) |
| — | `ai_chat_plan` | [plan](plan.md) |
| — | `ai_chat_workspace` | [workspace](workspace.md) |
| — | `ai_chat_citation` | [citation](citation.md) |
| — | `ai_chat_failure` | [failure](failure.md) |
| — | `ai_chat_payload` | [payload](payload.md) |
| — | `ai_chat_slash_menu` | [slash_menu](slash_menu.md) |

## The notes

### The spine
Every application that renders an agent needs all of these.

| Note | Tier | Converged in | Status |
|---|---|---|---|
| [transcript](transcript.md) | 2 | all three | built |
| [message](message.md) | 1 | all three | built |
| [streaming_markdown](streaming_markdown.md) | 3 | hooops | built |
| [tool_call](tool_call.md) | 2 | all three | built |
| [payload](payload.md) | 1 | all three | built |
| [composer](composer.md) | 2 | all three | built |
| [failure](failure.md) | 1 | all three | built |
| [plan](plan.md) | 1 | hooops, toybox | built |

### Stopping to ask
An agent that can only talk is a chatbot. These are the components for one that
stops and waits.

| Note | Tier | Converged in | Status |
|---|---|---|---|
| [request](request.md) | 2 | hooops, toybox | built |
| [permission](permission.md) | 2 | toybox | built |
| [proposal](proposal.md) | 1 | kp2 | built |

### Around the transcript

| Note | Tier | Converged in | Status |
|---|---|---|---|
| [reasoning](reasoning.md) | 1 | hooops, kp2 | built |
| [citation](citation.md) | 1 | kp2 | built |
| [welcome](welcome.md) | 1 | kp2, hooops | built |
| [attachments](attachments.md) | 2 | kp2, toybox | built |
| [slash_menu](slash_menu.md) | 2 | kp2, toybox | built |
| [workspace](workspace.md) | 1 | hooops, toybox | built |

### Parity with assistant-ui
None of the three applications has these. They are built in this round so that
`ai_chat_message` never has to change shape to admit them later.

| Note | Tier | Converged in | Status |
|---|---|---|---|
| [action_bar](action_bar.md) | 2 | none | built |
| [branch_picker](branch_picker.md) | 2 | none | built |

### Infrastructure, filed outside this folder
Generic elements the AI chat components need, useful well beyond them, so they sit
with the other component notes rather than in here:

- [`../auto_scroll.md`](../auto_scroll.md) — `<unmagic-autoscroll>`
- [`../optimistic.md`](../optimistic.md) — `<unmagic-optimistic>`
- [`../elapsed.md`](../elapsed.md) — `<unmagic-elapsed>`

## Decisions for this round

Settled ones stay listed so the reasoning isn't lost.

### Decided

- **The namespace is `ai_chat`.** `Unmagic::Components::AIChat::*`, helpers
  prefixed `ai_chat_`, CSS blocks named `UnmagicAIChat*`. Three names were
  weighed and the reasoning is kept here so it isn't relitigated:

  - ~~`assistant_*`~~ — rejected. `assistant` is a *role* the API already names
    (`role: user | assistant | tool`), so `assistant_message role: :user` reads
    as a contradiction. It is also taken: kp2 has thirteen `assistant_*` helpers
    and hooops two.
  - ~~`agent_*`~~ — rejected. Accurate for the whole surface, and the shortest,
    but `agent` is overloaded in the applications this ships into: hooops has
    `Theme::Agent` and three `user_agent` modules, so `UnmagicAgentMessage`
    invites a double-take at every call site.
  - **`ai_chat_*`** — chosen. Unambiguous, discoverable in the docs, and free of
    collisions in all three applications (bare `chat_*` is not — toybox has four).
    The gem uses explicit `require_relative` rather than Zeitwerk, so the `AI`
    acronym needs no inflection.

  The known cost, recorded rather than argued away: about a third of the family
  is not chat. `ai_chat_tool_call`, `ai_chat_payload`, `ai_chat_plan`,
  `ai_chat_workspace`, `ai_chat_permission` and `ai_chat_proposal` name a tool
  timeline, a code block, a checklist, a file list, a security gate and an inline
  offer. They are grouped under `ai_chat` because they are only ever reached
  through one, not because they are conversation. A note for one of these should
  describe what it actually is and not stretch the metaphor to fit its own name.

- **The root helper is bare `ai_chat`.** The transcript is the family's root, so
  it is `ai_chat do |chat|` rather than `ai_chat_transcript`, matching how `card`
  and `menu` are roots elsewhere in the gem. Every other helper keeps the prefix.
  This deliberately does *not* make `ai_chat` a builder that yields the composer,
  the plan and the workspace as parts: those are placed differently by all three
  applications, and a root that owned them would drag page layout into the gem.
  See open decision 1.

- **The gem does not parse Markdown.** All three applications have their own
  `Markdown` module with their own sanitiser, their own link handling and their
  own code highlighting, and none of that belongs in a view-component gem. The
  gem takes already-rendered, already-sanitised HTML, and owns only the prose
  styling around it (`UnmagicProse`) and the element that reveals it as it
  streams. This keeps the runtime dependencies at ActiveSupport, ActionView and
  Railties.

- **Code highlighting is a seam.** All three applications highlight tool
  payloads with Rouge, and the gem depends on no highlighter. `ai_chat_payload`
  renders through `Configuration#code_block`, called with `(view, source,
  language)`, whose default is an unhighlighted `<pre><code>`. See
  [payload](payload.md).

- **The elements are custom elements, not Stimulus.** Four of the pieces being
  brought across are Stimulus controllers today and have to be rewritten
  (`auto-scroll`, `optimistic`, `elapsed`, `slash-command`).
  `streaming-markdown` is already a custom element and lifts nearly verbatim.

- **These components need Turbo**, and say so in their import lines. The
  transcript is built on the `upsert` stream action the gem already ships, and
  `ai_chat_message`'s optimistic rendering is the client half of that same
  reconcile-by-id contract. This is the first component family in the gem that
  isn't optional about Turbo.

- ~~**Glyphs go into `Icons::PATHS`.**~~ **Superseded: glyphs render through
  `unmagic-icon`.** The gem now depends on unmagic-icon (and on unmagic-color,
  for avatar tints), and ships the Lucide SVGs it needs in
  `app/assets/icons/lucide`. A host needs no icon set of its own, which matters
  because kp2 downloads Phosphor rather than Lucide. `Icons.svg(view, :name)` is
  unchanged for callers.

- **Amber means waiting on a person.** All three applications arrived at this
  independently — a permission request, an unanswered question, a plan step
  parked on somebody. It is the one state that will not move on its own, so it
  is the one that carries a colour. Everything else is neutral, with red for
  failure and green for done.

### Still open

1. **How much of the transcript's layout the gem owns.** `ai_chat`
   renders the viewport and the spacing between entries, but the three
   applications each put the plan and workspace somewhere different — a floating
   right-hand panel (hooops), a docked sidebar (toybox), a slide-out panel
   (kp2). The note proposes the gem own the viewport and stay out of the page
   layout. Confirm before building.

2. **Whether `ai_chat_message` should render the entry, or only its chrome.** All
   three applications render a timeline of mixed entry types through
   `to_partial_path`, which is a Rails convention the gem shouldn't replace. The
   notes assume the host keeps its own partial per entry type and calls the
   gem's helper inside it. See [transcript](transcript.md).

3. **Branch storage.** [branch_picker](branch_picker.md) needs an opinion about
   what a branch *is* on the server, and no application here has one yet. The
   note proposes the gem stay agnostic: it renders counts and links the host
   supplies.
