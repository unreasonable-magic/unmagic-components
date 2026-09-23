# `message_actions`

> Status: built
> Tier: 2 (reuses `<unmagic-toolbar>`)
> Replaces or relates to: `ai_chat_action_bar` (now an alias of this), `message`,
> `copy_button`, `menu`

## Purpose

The controls on a message: reply, react, copy, edit, delete, a menu of more.
Rendered into `message.actions { }`, which places it for the variant, or on its
own.

This is `ai_chat_action_bar` moved out of the AI chat family with a generic
name. Nothing about a row of icon controls under a message was about agents.
The old helper stays as an alias.

## API

```erb
<%= message_actions for: dom_id(message) do |bar| %>
  <% bar.action "Reply", reply_path(message), icon: :reply %>
  <% bar.control { tag.button Unmagic::Components::Icons.svg(self, :smile_plus), type: "button", popovertarget: "picker_#{message.id}",
                   class: button_classes(:icon), "aria-label": "Add reaction", title: "Add reaction" } %>
  <% bar.copy message.body %>
  <% bar.action "Edit", edit_message_path(message), icon: :pencil %>
  <% bar.action "Delete", message_path(message), icon: :trash_2, method: :delete, confirm: "Delete this message?" %>
  <% bar.control { menu { |menu| menu.link "Pin", pin_path(message) } } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `for:` | element id | required | The message these act on; `aria-controls` |
| `reveal:` | `:hover`, `:always` | `:hover` | Whether the bar hides until the message is hovered or the bar focused |
| `label:` | string | "Message actions" | The toolbar's `aria-label` |

Builder parts:

- `bar.copy(text)` — `copy_button`, with its live "Copied" announcement.
- `bar.action(label, url, icon:, method: :get, confirm: nil, **options)` — an
  icon-only control: a `link_to` for a GET, a `button_to` otherwise.
- `bar.control { }` — any markup: a `menu`, a text button for an email's
  "Reply".

With no parts it renders nothing. Other options go on the element.

Inside a message, `m.actions(**options) { |bar| … }` builds this with `for:` set
to the message's id, so the id is written once. An email's actions are text
buttons through `bar.control` (`bar.action` is icon-only); the email variant
shows the bar whatever `reveal:` says, since there is nothing to hover for.

## Markup

```html
<unmagic-toolbar class="UnmagicMessageActions" role="toolbar" aria-label="Message actions" aria-controls="message_2" data-reveal="hover">
  <a class="UnmagicButton UnmagicButton--icon UnmagicMessageActions__action" aria-label="Reply" title="Reply" href="…">…</a>
  <form class="UnmagicMessageActions__form" …><button class="UnmagicButton UnmagicButton--icon UnmagicMessageActions__action" …>…</button></form>
</unmagic-toolbar>
```

## Accessibility

- The WAI-ARIA toolbar pattern: `role="toolbar"`, a label, `aria-controls`
  naming the message; `<unmagic-toolbar>` gives it one Tab stop with Left,
  Right, Home and End between controls.
- Every control is icon-only, so every control has an `aria-label` and a
  matching `title`.
- `reveal: :hover` hides the bar with opacity, never `display: none`, so it
  stays in the tab order and appears the moment it takes focus. On a touch
  screen it is always shown.

## Styling

CSS section: **Message actions**.

- `.UnmagicMessageActions`, `__action`, `__form`
- `[data-reveal="hover"]` is `opacity-0` with a 150ms transition, `opacity-100`
  under `.UnmagicMessage:hover` and on `:focus-within`, and always under
  `@media (hover: none)`. Reduced motion drops the transition.
- Icon buttons are `p-1` with `size-3.5` glyphs. Forms inside are
  `m-0 inline-flex`.
- Where the bar sits (beside a bubble, floating over a row, under an email) is
  `message`'s CSS on `UnmagicMessage__actions`.

## Small screens

Always visible under `hover: none`; the controls are `UnmagicButton`s, 44px under
a coarse pointer.

## Behaviour (JavaScript)

`<unmagic-toolbar>` (`toolbar.js`), unchanged: a roving tabindex that rescans when
its contents change. Turbo-safe; nothing to reset before cache.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.message.actions.label` | "Message actions" |

The default falls back to the old `unmagic.components.ai_chat.action_bar.label`
before the English, so a host that translated the AI chat key keeps its
translation. The action labels are the caller's words.

## Specs

`spec/unmagic/components/messaging_spec.rb`:

- `role="toolbar"`, `aria-label`, `aria-controls` from `for:`, `data-reveal`.
- `copy` renders the copy button; `action` renders a link for a GET and a
  `button_to` with `data-turbo-confirm` otherwise; every control has
  `aria-label` and `title`.
- `reveal:` validated; blank `for:` raises; no parts renders nothing.
- `ai_chat_action_bar` renders the same thing.

## Preview

Page: `message_actions`. A bar on a row (hover to see it), one with
`reveal: :always`, and one with a menu in it.

By hand: Tab into the bar and confirm it appears; Left/Right/Home/End; copy
announces; a phone width shows it without hover; dark theme; reduced motion.
