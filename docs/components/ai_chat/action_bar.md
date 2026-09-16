# `ai_chat_action_bar`

> Status: built
> Tier: 2 (small element)
> Relates to: [message](message.md), [branch_picker](branch_picker.md), `copy_button`, `tooltip`

## As built

Where the build differs from this note:

- `bar.action(label, url, icon:, method:, confirm:)` takes the url positionally.
- The toolbar's controls are its buttons, links and anything with a tabindex, skipping disabled and hidden ones.

## Purpose

The controls under a turn: copy it, run it again, edit it, read it aloud. It is
assistant-ui's `ActionBarPrimitive`, and **none of the three applications here has
one** — they are built in this round so [message](message.md) never has to change
shape to admit them later.

The argument for building it now rather than later: every one of these
applications has a "the reply was wrong" path that currently means retyping the
question, and hooops already grew a Retry button inside its failure card, which is
this component arriving one action at a time in the wrong place.

For controls that act on a turn. Not for controls that act on the conversation —
that is page chrome.

## API

```erb
<%= ai_chat_action_bar for: dom_id(message) do |bar| %>
  <% bar.copy message.content %>
  <% bar.action "Try again", icon: :rotate, url: retry_path(message), method: :post %>
  <% bar.action "Edit", icon: :pencil, url: edit_message_path(message) %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `for:` | element id | required | The turn these act on; names the bar for assistive tech |
| `reveal:` | `:hover`, `:always` | `:hover` | Whether the bar hides until the turn is hovered or focused |

Builder parts:

- `bar.copy(text)` — the gem's existing `copy_button`, with its live-region
  "Copied" announcement already solved.
- `bar.action(label, icon:, url:, method:, confirm:)` — a `button_to` for a
  non-GET, a `link_to` otherwise, per the gem's rule.
- `bar.control { }` — arbitrary markup, for anything else.

With no parts it renders nothing.

`reveal: :hover` is the convention and it is also an accessibility trap, which is
why it is an option with a documented escape and why the CSS below uses
`:focus-within` as well as `:hover`.

## Markup

```html
<div class="UnmagicAIChatActionBar" role="toolbar"
     aria-label="Message actions" aria-controls="message_2" data-reveal="hover">
  <button class="UnmagicAIChatActionBar__action" type="button">…</button>
</div>
```

## Accessibility

- `role="toolbar"` with an `aria-label`, and `aria-controls` naming the turn, so
  a reader arriving at the bar knows which turn it belongs to.
- A toolbar is a composite: **roving tabindex**, with Left/Right (and Home/End)
  moving between the controls and a single Tab stop for the whole bar. This is
  the WAI-ARIA toolbar pattern and it is the reason this needs script at all.
- Every control is icon-only, so every control has an `aria-label` and a matching
  `title`, per the gem's existing rule.
- **The bar is never hidden from the keyboard.** `reveal: :hover` hides it
  visually on `:hover`/`:focus-within`, never with `display: none` or
  `visibility: hidden`, so it stays in the tab order and appears the moment it
  takes focus. A bar that only exists for a mouse is the standard failure of this
  pattern.
- Copy announces through `copy_button`'s existing polite live region.

## Styling

CSS section: **AI chat action bars**.

- `.UnmagicAIChatActionBar`, `__action`

```css
.UnmagicAIChatActionBar[data-reveal="hover"] { @apply opacity-0 transition-opacity; }
.UnmagicAIChatMessage:hover  .UnmagicAIChatActionBar[data-reveal="hover"],
.UnmagicAIChatActionBar[data-reveal="hover"]:focus-within { @apply opacity-100; }
@media (prefers-reduced-motion: reduce) { .UnmagicAIChatActionBar { @apply transition-none; } }
```

Opacity rather than `display`, for the keyboard reason above. Under a coarse
pointer (`@media (hover: none)`) the bar is always visible — there is no hover on
a touch screen, and a bar that needs one is a bar that does not exist.

Controls: `rounded-md p-1.5 text-neutral-500 hover:bg-neutral-100
hover:text-neutral-900`, dark pairs, shared focus ring.

## Behaviour (JavaScript)

`<unmagic-toolbar>` — a general roving-tabindex toolbar, not an agent-specific
element, so it is named generically and any component with a row of controls can
use it.

- On connect, the first enabled control gets `tabindex="0"` and the rest `-1`.
- Left/Right move and wrap; Home/End jump; the moved-to control takes focus and
  the tabindex.
- `observedAttributes` covers nothing; it re-scans its controls on
  `turbo:morph` and via a `MutationObserver`, so a streamed-in or re-rendered bar
  works without a second initialisation path.
- Turbo: listeners on the element in the constructor; nothing to reset before
  cache.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.action_bar.label` | "Message actions" |

The action labels are the caller's words.

## Specs

`spec/unmagic/components/ai_chat_action_bar_spec.rb`:

- `role="toolbar"`, `aria-label`, `aria-controls` from `for:`.
- `copy` renders the gem's copy button.
- `action` renders a `button_to` for a non-GET and a `link_to` for a GET.
- Every control has both `aria-label` and `title`.
- `reveal:` sets `data-reveal`; `ArgumentError` for an unknown value.
- No parts renders nothing.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A bar under an assistant turn with copy, retry and edit; one with
`reveal: :always`; and one with a single control.

By hand: **Tab into the bar and confirm it appears** — the whole accessibility
argument is that one check. Then Left/Right/Home/End; copy announces; a
touch-sized viewport shows the bar without hover; dark theme; reduced motion.

## Open questions

- Should "speak" ship? kp2 has voice output and it is the obvious fourth action.
  Proposed: not as a built-in — `bar.control` takes it, and speech synthesis is a
  subsystem, not a button.
