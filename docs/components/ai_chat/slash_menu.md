# `ai_chat_slash_menu`

> Status: draft
> Tier: 2 (small element)
> Relates to: [composer](composer.md), [`../position`](../position.md), [`../combobox`](../combobox.md), [`../command_palette`](../command_palette.md)

## Purpose

The agent's skills, prompts or procedures, offered as slash commands. Type `/`
where a word would start and the menu opens; keep typing to narrow it; arrows to
move; Enter or Tab to take one. Picking writes `/name ` into the message — the
agent reads the name and loads the procedure itself, so nothing about the message
is special by the time it is sent.

kp2 and toybox both built this. kp2's rides its rich-text editor's own prompt
mechanism; toybox's is a plain server-rendered menu filtered in the browser.
toybox's is the one to bring across, because it depends on nothing.

The key property both share: **the menu is rendered by the server with every item
in it and filtered here, so what can be offered is only ever what actually
exists.** No search endpoint, no stale list.

Not [`command_palette`](../command_palette.md), which is a page-wide launcher
opened by a hotkey. Not [`combobox`](../combobox.md), which is a form control
that holds a value.

## API

```erb
<%= ai_chat_slash_menu above: true do |menu| %>
  <% skills.each do |skill| %>
    <% menu.item skill.name, description: skill.description %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `trigger:` | string | `"/"` | One character |
| `above:` | boolean | `false` | Open upwards; a composer at the foot of a page needs it |
| `insert:` | string | `"%{name} "` | What is written, given the item's name |

Builder part: `menu.item(name, description:, icon:, arguments:)`.

- `arguments:` renders the parameter hints after the name (`/invite [email]`),
  which both applications show and which is the difference between a menu and a
  list of words.
- With no items it renders nothing: an agent with no skills should have no menu,
  not an empty one.

The menu is a sibling of the composer's field, not a child of the form's field,
and the note says so because the ordering is load-bearing: the menu takes the
arrow keys and Enter for itself while it is open, stopping the event where it
stands, so a message cannot be sent out from under it.

## Markup

```html
<unmagic-slash-menu trigger="/" class="UnmagicAIChatSlashMenu" hidden>
  <ul role="listbox" aria-label="Commands">
    <li role="option" class="UnmagicAIChatSlashMenu__item" data-name="curating" aria-selected="true">
      <span class="UnmagicAIChatSlashMenu__name">/curating <span class="UnmagicAIChatSlashMenu__argument">[shelf]</span></span>
      <span class="UnmagicAIChatSlashMenu__description">…</span>
    </li>
  </ul>
</unmagic-slash-menu>
```

Every item is rendered; filtering hides them. That is what makes the component
work with no request and no server round trip.

## Accessibility

- The WAI-ARIA [combobox pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/)
  with a listbox popup, which is the pattern for a text field with a filtered
  menu attached.
- The field gets `role="combobox"`, `aria-expanded`, `aria-controls` and
  `aria-activedescendant` pointing at the selected option — focus stays in the
  textarea throughout, which is essential: the reader is in the middle of typing
  a sentence.
- Keyboard: Down/Up move, Home/End jump, Enter and Tab take, Escape closes and
  leaves what was typed. Every one of those `preventDefault`s and
  `stopImmediatePropagation`s while the menu is open.
- Selection is `[aria-selected]` on the option, which is also what styles it — no
  state class.
- The menu closes on blur, but selection is taken on `mousedown` rather than
  `click`, which fires before the box loses focus, so the cursor is still where
  the name has to be written.

## Styling

CSS section: **AI chat slash menu**.

- `.UnmagicAIChatSlashMenu`, `--above`, `__item`, `__name`, `__argument`,
  `__description`

Floats rather than pushing the page around: absolute, `max-h-64 overflow-y-auto
rounded-xl border bg-white p-1 shadow-lg`, dark pairs. `--above` is
`bottom-full mb-2`; the default is `top-full mt-2`.

Selection: `.UnmagicAIChatSlashMenu__item[aria-selected="true"] { @apply
bg-neutral-100 dark:bg-neutral-800; }`.

Motion: none — a menu that animates open cannot keep up with typing.

## Behaviour (JavaScript)

`<unmagic-slash-menu>` — reads `trigger`, `above`, `insert`.

- The token is `/(?:^|\s)\/([\w-]*)$/` against the text *before the cursor*, so a
  slash inside a path already written further back is not a command.
- On `input`: match the token, filter by prefix, show or close.
- On `keydown` while open: the keys above, each stopping the event.
- Writing replaces the token in place and puts the cursor after the trailing
  space, since something always follows.
- Fires `unmagic-slash-menu:pick`, bubbling.
- Turbo: listeners on the field are added in the constructor via the element's
  own scope; `turbo:before-cache` closes the menu, so a restored snapshot is not
  stuck open. Needs no Turbo.

**This should be built after [`../position.md`](../position.md).** Anchored
placement is already a decided piece of shared infrastructure for tooltip,
popover, menu, context menu and combobox, and a slash menu that hand-rolls its
own placement would be the sixth copy of it.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.slash_menu.label` | "Commands" |

## Specs

`spec/unmagic/components/ai_chat_slash_menu_spec.rb`:

- Every item renders, with `role="option"` and `data-name`.
- The first item is `aria-selected` on render.
- `arguments:` renders hints; omitting them renders none.
- `above:` classes.
- No items renders nothing at all.
- `trigger:` and `insert:` reach the element.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A composer with a menu of eight skills, one with arguments, and a
second composer with `above: false` so both placements can be checked.

By hand: type `/`, then narrow to nothing (the menu must close), arrows wrap at
both ends, Enter takes without sending the message, Escape closes and leaves the
text, a slash mid-path does not open it, picking with the mouse works; dark
theme.

## Open questions

- Should the trigger be able to be more than one character (`@` for people, `#`
  for files)? Both applications ship exactly one. Proposed: one element per
  trigger, several elements allowed on one field. That needs no API change and
  keeps each menu's item list separate.
