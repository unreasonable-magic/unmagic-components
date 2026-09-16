# `ai_chat_composer`

> Status: draft
> Tier: 2 (small element)
> Relates to: [message](message.md), [attachments](attachments.md), [slash_menu](slash_menu.md), `autogrow_text_area`, `<unmagic-optimistic>`, `<uuid-input>`

## Purpose

The box a person types into, and the one button at the end of it: Send, or Stop
while a turn is actually running.

For the bottom of a transcript, and for the page a conversation is started from —
they ask the same thing of a person and they read the same, so they are one
component. Not for an ordinary form; this one is shaped entirely around a turn
being in flight.

## API

```erb
<%# On a chat that exists %>
<%= form_with model: Message.new, url: chat_messages_path(chat), id: "composer" do |form| %>
  <%= ai_chat_composer form: form, field: :content, state: chat.run_state,
        placeholder: "Ask for something…" do |composer| %>
    <% composer.optimistic id: "message[client_id]", container: "#entries" %>
    <% composer.attach { … } %>
    <% composer.menu { ai_chat_slash_menu … } %>
  <% end %>
<% end %>

<%# Before there is a chat: no optimistic bubble, because there is no transcript %>
<%= ai_chat_composer form: form, field: :prompt, state: :idle, label: "Start chat", rows: 4 %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `form:` | form builder | required | The composed field belongs to it |
| `field:` | symbol | required | |
| `state:` | `:idle`, `:running`, `:stopping`, `:waiting` | `:idle` | Validated; raises `ArgumentError` |
| `label:` | string | "Send" | The idle button's label |
| `stop_form:` | id | `"stop_turn"` | The form the Stop button submits |
| `placeholder:` | string | `nil` | |
| `rows:` | integer | `2` | |

Builder parts: `composer.optimistic(id:, container:)`, `composer.attach { }`,
`composer.menu { }`, `composer.actions { }` (extra controls before the button).

Two things about this API are load-bearing, and both are lessons the applications
learned the hard way:

**Neither button is nested in the form it submits.** Both carry a `form`
attribute naming one by id. That is what lets the action region be redrawn on its
own when the state changes — and it has to be, because replacing the whole
composer would take the half-typed next question and the attached files with it,
which is a high price for swapping one word. The component renders the action
region with a stable id (`#{form_id}_action`) and documents it as the broadcast
target.

**The textarea is always typeable.** Only the button flips. An in-progress draft
is never cleared by a state change, and `state:` never disables the field.

`state: :waiting` — a turn parked on a question — shows a "Waiting for your
input…" hint beside Stop, because a composer that looks idle while the agent is
blocked on a form above it is a small lie.

## Markup

```html
<div class="UnmagicAIChatComposer">
  <div class="UnmagicAIChatComposer__menu">…</div>
  <div class="UnmagicAIChatComposer__chips">…</div>

  <div class="UnmagicAIChatComposer__box">
    <uuid-input name="message[client_id]"></uuid-input>
    <textarea class="UnmagicAIChatComposer__field UnmagicInput" rows="2"></textarea>
    <label class="UnmagicAIChatComposer__attach">…</label>

    <div id="composer_action" class="UnmagicAIChatComposer__action">
      <button type="submit" form="composer" class="UnmagicButton UnmagicButton--primary">Send</button>
    </div>
  </div>

  <template>…the optimistic bubble…</template>
</div>
```

The field is an `autogrow_text_area`, which the gem already ships, with a
`max-h-*` so it grows to fit and only then scrolls.

## Accessibility

- Enter sends, Shift+Enter makes a newline. Enter only sends when a submit
  control for the form is actually present — so while a turn is running, Enter
  does nothing rather than silently failing.
- The Stop button is a real submit for a separate, empty form. Stopping asks
  nothing of the person and the composer's contents are none of its business, so
  pressing Stop leaves the half-typed next question exactly where it was.
- `:stopping` renders a disabled button reading "Stopping…", not a button still
  reading "Stop". A turn stops at the next tool call it would have made, which is
  long enough that a button still reading Stop looks like one that didn't work
  and gets pressed again.
- The action region is `aria-live="polite"`, so a non-visual reader hears the
  turn start and finish. This is the only live region the composer has.
- The attach control is a `<label>` over a visually hidden file input, so it can
  be styled like the button beside it while staying a real file input for the
  keyboard.
- The field has a visible label or an `aria-label`; a placeholder is not a label.

## Styling

CSS section: **AI chat composer**.

- `.UnmagicAIChatComposer`, `__box`, `__field`, `__attach`, `__action`, `__chips`,
  `__menu`, `__hint`

The box: `rounded-xl border border-neutral-300 bg-white p-2` with
`focus-within:border-neutral-500`, and the dark pairs. The field is transparent
and borderless inside it, so the box is the control and the focus ring belongs to
the box — `focus-within` rather than `:focus-visible` on the field, which is the
one place in the gem that is right.

State is attribute-driven: the action region's content is what changes, so there
are no composer state classes at all.

Motion: none.

## Behaviour (JavaScript)

No element of its own. It composes:

- `autogrow` (already in the gem) on the field.
- `<uuid-input>` (already in the gem) when `optimistic` is used.
- `<unmagic-optimistic>` for the bubble.
- Enter-to-send, wired by delegation from `document` on
  `.UnmagicAIChatComposer__field`, guarded with a `Symbol.for` flag — the
  "behaviour on plain elements" rule, so a composer streamed in later works with
  no setup.

On `turbo:submit-end` with `success`, the form is reset rather than the field
blanked, so `<uuid-input>` hears the reset and mints the id the next question
will be drawn under. Clearing on submit-end rather than on keypress means a
request that fails leaves what was typed where it was.

Needs Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.composer.send` | "Send" |
| `unmagic.components.ai_chat.composer.stop` | "Stop" |
| `unmagic.components.ai_chat.composer.stopping` | "Stopping…" |
| `unmagic.components.ai_chat.composer.waiting` | "Waiting for your input…" |
| `unmagic.components.ai_chat.composer.attach` | "Attach a file" |

## Specs

`spec/unmagic/components/ai_chat_composer_spec.rb`:

- Each state's action region: the button, its `form` attribute, its label, and
  `disabled` on `:stopping` only.
- The action region's id is derived from the form's id and is stable across
  states.
- The field is never disabled, in any state.
- The field is an autogrow textarea carrying the control class.
- `optimistic` renders `<uuid-input>` and the template with the named fields;
  omitting it renders neither.
- Each builder part in its position.
- `ArgumentError` for an unknown state.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. All four states side by side, one with attachments and a slash
menu, and one in a narrow column to check the box at small widths.

By hand: Enter and Shift+Enter; Enter while `:running` (must do nothing); type a
draft then switch the state and confirm the draft survives; tab order through
field, attach, button; dark theme.

## Open questions

- Should `ai_chat_composer` render the `<form>` itself rather than taking one?
  Taking one keeps `form_with` and the host's URL, CSRF and Turbo options where
  the host can see them, at the cost of an awkward two-element setup for the Stop
  form. Proposed: keep taking one, and have the helper render the empty stop form
  as a sibling when `stop_form:` is left at its default.
