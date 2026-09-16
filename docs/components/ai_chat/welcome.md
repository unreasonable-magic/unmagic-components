# `ai_chat_welcome`

> Status: built
> Tier: 1 (no JS)
> Relates to: [transcript](transcript.md), [composer](composer.md), `empty_state`

## As built

Where the build differs from this note:

- `field:` is built. Suggestions are wired in `ai_chat.js`.

## Purpose

What a conversation with nothing in it says, and the suggestions that get one
started. assistant-ui's `Thread.Welcome` plus `Suggestions`.

kp2 built the chips — prompts narrowed to the page the reader is on — and hooops
built the placeholder version, a real doable prompt rotated into the composer's
placeholder text. Both are answers to the same problem: a person facing an empty
box does not know what the agent can do, and a generic "Ask me anything" tells
them nothing.

The rule both applications landed on and this component keeps: **a suggestion
must be genuinely runnable**, naming the reader's own data where there is some.
"Draft a follow-up for Ana" beats "Draft a follow-up for a candidate", and both
beat "Summarise something".

Not `empty_state`, which is the gem's blank slate for a table. This one has
actions that put text in a box rather than links to elsewhere.

## API

```erb
<%= ai_chat_welcome heading: "What can I help with?" do |welcome| %>
  <% welcome.body "It can search your jobs, draft messages and update records." %>
  <% welcome.suggestion "Who hasn't replied yet?", icon: :inbox %>
  <% welcome.suggestion "Draft a follow-up for Ana", icon: :pen %>
  <% welcome.suggestion "Create a job at Acme", icon: :plus, fill: true %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `heading:` | string | required | |
| `heading_tag:` | symbol | `:h2` | |
| `composer:` | id | `"composer"` | The form a suggestion sends into |
| `field:` | name | `nil` | The field a suggestion fills; inferred from the form |

Builder parts: `welcome.body(text)`, `welcome.suggestion(text, icon:, fill:,
value:)`.

- `fill: true` completes the line in the composer instead of sending it, for a
  suggestion that cannot be sent as-is — a prompt taking arguments. kp2 makes
  exactly this split and it is right.
- `value:` is what is actually put in the box, where the chip's label is shorter
  than the prompt.
- With no suggestions it renders the heading and body alone, which is the correct
  welcome for an agent with nothing to suggest.

## Markup

```html
<div class="UnmagicAIChatWelcome">
  <h2 class="UnmagicAIChatWelcome__heading">What can I help with?</h2>
  <p class="UnmagicAIChatWelcome__body">…</p>

  <ul class="UnmagicAIChatWelcome__suggestions">
    <li>
      <button type="button" class="UnmagicAIChatWelcome__suggestion"
              data-ai-chat-suggestion="Who hasn't replied yet?"
              data-ai-chat-suggestion-form="composer">
        <svg aria-hidden="true">…</svg> Who hasn't replied yet?
      </button>
    </li>
  </ul>
</div>
```

Buttons, not links: a suggestion puts text in a box on this page. A link would
promise navigation.

## Accessibility

- A real heading at a level the caller chooses, so the welcome fits the page's
  outline.
- The suggestions are a list of buttons, so a screen reader announces how many
  there are before reading them.
- Pressing a send-suggestion moves focus to the composer field, because the
  reader's next action is either typing or watching the reply, and both want
  focus there. Pressing a `fill:` one leaves the cursor at the end of the filled
  text.
- Icons are `aria-hidden`; each chip's label is its full text.

## Styling

CSS section: **AI chat welcome**.

- `.UnmagicAIChatWelcome`, `__heading`, `__body`, `__suggestions`, `__suggestion`

Chips: `rounded-full border border-neutral-200 px-3 py-1.5 text-sm
text-neutral-600 hover:bg-neutral-50`, dark pairs, `focus-visible` using the
gem's shared focus ring.

The welcome centres in the transcript's empty viewport. No colours beyond
neutrals — this is the quietest surface in the family.

Motion: none.

## Behaviour (JavaScript)

No element. Wired by delegation from `document` on `[data-ai-chat-suggestion]`,
guarded with a `Symbol.for` flag, so a welcome streamed into an empty transcript
works with no setup.

- Fill the named form's field with the suggestion's value.
- Dispatch an `input` event, so `autogrow` resizes the textarea.
- Unless `data-ai-chat-suggestion-fill`, submit the form — but only when a submit
  control for it is present, which is the same guard [composer](composer.md)
  uses, so a suggestion cannot send while a turn is running.

Needs Turbo only insofar as the composer does.

## I18n

None. Every word is the caller's.

## Specs

`spec/unmagic/components/ai_chat_welcome_spec.rb`:

- Heading, `heading_tag:`, and body.
- Suggestions render as buttons in a list, with `data-ai-chat-suggestion` carrying
  `value:` where given and the label otherwise.
- `fill: true` adds `data-ai-chat-suggestion-fill`.
- `composer:` reaches every chip.
- No suggestions renders no list element at all.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A welcome with four suggestions above a live composer, so pressing
one can be seen to fill and send; one with a `fill:` suggestion; and one with no
suggestions.

By hand: keyboard through the chips; press one while the composer is `:running`
(it must fill but not send); dark theme.

## Open questions

- Should suggestions be available under a running conversation too, as follow-up
  prompts? assistant-ui puts them only in the welcome. Proposed: the component
  does not care — it renders wherever it is put — so this is the host's call and
  the note stays silent rather than adding an option.
