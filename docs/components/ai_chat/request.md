# `ai_chat_request`

> Status: built
> Tier: 2 (small element)
> Relates to: [permission](permission.md), [tool_call](tool_call.md), `card`, `FormBuilder`

## As built

Where the build differs from this note:

- `request.question` takes `picked:` for an answered card, and the helper takes `method:` and `scope:` for the form.
- Focus-on-arrival lives in `ai_chat.js`, and applies only to a card rendered with `live: true`.

## Purpose

The agent asking something it cannot work out on its own, with the answers to it
right there rather than a sentence somebody has to reply to. The work has stopped
and it is waiting on a person.

Two applications built this, and they built two different shapes of it:

- **toybox** asks in choices — one or more questions, each with labelled options
  and a description, single- or multi-select.
- **hooops** asks with a form built from a JSON schema, which is what MCP's
  elicitation is.

They are the same component. The ask, the waiting, the answered state and the
place it sits in the transcript are identical; only the control differs. One
component with two faces is right, and two components that share all of that
would drift the way `auto_scroll` did.

Not for a permission grant — that is [permission](permission.md), which is a
different decision with different stakes and its own confirmation.

## API

```erb
<%# Choices %>
<%= ai_chat_request state: :waiting, url: answer_path(chat), id: dom_id(call) do |request| %>
  <% request.question "Which one?", header: "Scope", multiple: false do |q| %>
    <% q.option "This chat", description: "Only the conversation it asked about" %>
    <% q.option "Any chat", description: "Every conversation, from now on" %>
  <% end %>
  <% request.aside "Or say something else in the box below." %>
<% end %>

<%# A form, built by the caller %>
<%= ai_chat_request state: :waiting, url: elicitation_path(e), id: dom_id(e),
      prompt: e.prompt do |request| %>
  <% request.form do |form| %>
    <%= render "shared/schema_fields", form: form, schema: e.schema %>
  <% end %>
  <% request.decline "Decline" %>
<% end %>

<%# Answered %>
<%= ai_chat_request state: :accepted, id: dom_id(e), prompt: e.prompt do |request| %>
  <% e.answers.each { |label, value| request.answer label, value } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `state:` | `:waiting`, `:accepted`, `:declined`, `:cancelled`, `:timed_out` | required | Validated; raises `ArgumentError` |
| `url:` | path | required when `:waiting` | |
| `method:` | symbol | `:patch` | |
| `prompt:` | string | `nil` | The sentence above the questions |
| `id:` | string | `nil` | For `upsert` |
| `label:` | string | "Answer" | The submit's label |

Builder parts: `request.question(text, header:, multiple:) { |q| q.option … }`,
`request.form { |form| }`, `request.answer(label, value)`,
`request.decline(label)`, `request.aside(text)`.

`question` and `form` are mutually exclusive; using both raises `ArgumentError`
at render, the way `tabs.rb` validates its combinations.

**It keeps its questions after they are answered.** What was asked is most of
what the card is worth reading later: an answer on its own is a word with nothing
around it, and the reason the work went the way it did is the question somebody
was put in front of. Only the *options* go, replaced by what was picked. This is
toybox's rule and it is the single best decision in either implementation.

The heading changes tense once answered — "Wants to know" becomes "Wanted to
know" — because a heading still saying somebody wants something is the one line
in the card that would no longer be true.

`decline` posts the same form with a flag and `formnovalidate`, so it is one form
rather than a nested `button_to`, and needs no filled-in fields.

## Markup

```html
<div id="elicitation_3" class="UnmagicAIChatRequest UnmagicAIChatRequest--waiting">
  <div class="UnmagicAIChatRequest__head">
    <svg aria-hidden="true">…</svg> Wants to know
  </div>
  <p class="UnmagicAIChatRequest__prompt">…</p>

  <form action="…" method="post">
    <fieldset class="UnmagicAIChatRequest__question">
      <legend>
        <span class="UnmagicAIChatRequest__header">Scope</span>
        <span class="UnmagicAIChatRequest__label">Which one?</span>
      </legend>
      <label class="UnmagicAIChatRequest__option">
        <input type="radio" name="answers[0][]" value="This chat" required>
        <span>…</span>
      </label>
    </fieldset>

    <div class="UnmagicAIChatRequest__actions">…</div>
  </form>
</div>
```

Real `<fieldset>`/`<legend>` and real radios and checkboxes. A styled option is
still an input, drawn with `appearance: none`, exactly as the gem's own
`check_box_field` is.

## Accessibility

- Each question is a `<fieldset>` with a `<legend>`, so the question is announced
  with its options rather than sitting above them as a loose paragraph.
- A single-select question's inputs are `required`, so a question skipped by
  accident is not a question the agent has to ask again.
- `state: :waiting` streamed into the transcript carries `role="alert"`: the work
  has stopped and the reader needs to know. On page load it does not, for the
  same reason [failure](failure.md) does not.
- The answered card is ordinary content: nothing is announced when a decision
  the reader made is echoed back to them.
- Options are `<label>`-wrapped, so the whole card is a click target and the
  label is the accessible name.
- Focus moves to the first option when the card is streamed in and nothing else
  holds focus. If the reader is typing in the composer, focus stays where it is —
  the aside says they can answer there instead.

## Styling

CSS section: **AI chat requests**.

- `.UnmagicAIChatRequest`, `--waiting`, `--accepted`, `--declined`,
  `--cancelled`, `--timed_out`
- `__head`, `__prompt`, `__question`, `__header`, `__label`, `__option`,
  `__answer`, `__actions`, `__aside`

Waiting: `rounded-xl border border-amber-300 bg-amber-50` with
`dark:border-amber-800 dark:bg-amber-950/40`. Amber is the family's "waiting on a
person" colour.

Answered cards recede to neutral; declined and cancelled dim further with
`opacity-60`, so they read as dismissed.

Option state comes from `:has(:checked)`, not a class:

```css
.UnmagicAIChatRequest__option:has(:checked) { @apply border-amber-400 bg-amber-100/60; }
```

Forced colours: the radios and checkboxes are CSS-drawn, so they need the
`@media (forced-colors: active)` fallback the gem's own checks have.

## Behaviour (JavaScript)

None of its own. The focus-on-arrival behaviour is delegated from `document` on
`.UnmagicAIChatRequest--waiting`, guarded by a `Symbol.for` flag and a check that
focus is not already inside a form — one small piece of behaviour, and it belongs
here rather than in every host.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.request.waiting` | "Wants to know" |
| `unmagic.components.ai_chat.request.asked` | "Wanted to know" |
| `unmagic.components.ai_chat.request.answer` | "Answer" |
| `unmagic.components.ai_chat.request.decline` | "Decline" |
| `unmagic.components.ai_chat.request.accepted` | "Submitted" |
| `unmagic.components.ai_chat.request.declined` | "Declined" |
| `unmagic.components.ai_chat.request.cancelled` | "Cancelled" |
| `unmagic.components.ai_chat.request.timed_out` | "Timed out" |
| `unmagic.components.ai_chat.request.unanswered` | "No answer." |

## Specs

`spec/unmagic/components/ai_chat_request_spec.rb`:

- Each state's classes, heading and tense.
- A waiting card renders a form and options; an answered one renders the
  questions with picked answers and no inputs at all.
- `multiple: true` renders checkboxes and drops `required`.
- `decline` renders `formnovalidate` and a named value in the same form.
- `question` and `form` together raise `ArgumentError`.
- An unknown state raises `ArgumentError`.
- `role="alert"` only when `live: true`.
- Fieldset/legend structure, and the `name` indexing across several questions.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A single-choice question; a multi-choice one; two questions in one
card; a schema-built form; and one card in each answered state.

By hand: keyboard through the options; submit with nothing picked (it must
refuse); dark theme; forced-colours mode.

## Open questions

- Should the gem build the form from a JSON schema itself, rather than taking a
  block? hooops has a `shared/_schema_fields` partial that does it. Proposed: no
  for this round — schema-to-field mapping is a component of its own with its own
  design problems, and `request.form` takes a block precisely so it can be added
  later without changing this API.
