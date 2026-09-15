# `hotkey`

> Status: draft
> Tier: 2 (small element: document-level delegation, no wrapper)
> Replaces or relates to:
> - Rails Blocks "KBD & Hotkey" (the gap source; this note is the hotkey half)
> - `kbd.md` (the static key hint), `dialog.js` (delegation pattern), `menu`, `tabs`

## Purpose

Gives an existing link, button or field a keyboard shortcut. Pressing the
shortcut clicks the element, or focuses it if it's a field. Examples:
- `/` focuses search
- `c` opens "New issue"
- `mod+enter` submits a form

It is **not** a command palette (see `command_palette.md`) and not a way to add
behaviour that has no visible control. Every hotkey belongs to an element on
the page, so the action stays discoverable and works without the keyboard.

## API

```erb
<%= link_to "New issue", new_issue_path, **hotkey("c", class: button_classes(:primary)) %>
<%= search_field_tag :q, nil, **hotkey("/", placeholder: "Search") %>
<%= form.submit "Send", **hotkey("mod+enter") %>

<%# Show the shortcut beside the label, rendered by kbd (kbd.md) %>
<%= link_to new_issue_path, **hotkey("c", class: button_classes) do %>
  New issue <%= kbd hotkey: "c" %>
<% end %>
```

`hotkey(keys, **options)` returns `options` with the hotkey attributes merged
in. `data:` and `aria:` hashes passed in are merged, not replaced. This works
with any tag helper, `link_to`, `button_to` or `form.submit`.

**Key syntax:**
- A combination is `+`-joined, e.g. `mod+shift+k`.
- Modifiers are `mod`, `ctrl`, `alt`, `shift` and `meta`.
- `mod` is ⌘ on Apple platforms and Ctrl elsewhere. For how it is *shown*,
  see "Platform modifier" in `kbd.md`; both notes follow that one rule.
- Keys are compared case-insensitively on `KeyboardEvent.key`, plus the names
  `enter`, `escape`, `space`, `up`, `down`, `left` and `right`.
- **No sequences in v1 (decided).** One `keys` string is one combination.
  Space-separated sequences like `"g i"` are future work (see below).

**Validation in Ruby** (`ArgumentError`):
- an unknown modifier or named key
- an empty string
- a sequence (any whitespace in `keys`): "hotkey sequences aren't supported"
- combinations the browser reserves and won't let pages have: `mod+w`, `mod+t`,
  `mod+n`, `mod+q`, `mod+shift+t`, `mod+tab`
- a single plain printable key other than `/` or `?` combined with
  `in_fields: true`

| Option | Values | Default | Notes |
|---|---|---|---|
| `in_fields:` | boolean | true if the keys include `mod`, `ctrl`, `alt` or `meta`, otherwise false | Whether it fires while typing in a field |
| `scope:` | `:page`, `:dialog` | `:page` | `:dialog` fires only while the element is inside an open modal dialog |

## Markup

```html
<a href="/issues/new" class="UnmagicButton UnmagicButton--primary"
   data-unmagic-hotkey="c" aria-keyshortcuts="C">New issue</a>
<button type="submit" data-unmagic-hotkey="mod+enter" data-unmagic-hotkey-in-fields
        aria-keyshortcuts="Control+Enter Meta+Enter">Send</button>
```

- `aria-keyshortcuts` is rendered on the server in ARIA's syntax. `mod` lists
  both platform forms, because the server doesn't know the platform.
- No wrapper element is added: it's an attribute on the caller's element.
- Without JavaScript nothing happens, and the control is still clickable.

## Accessibility

- **Screen readers:** `aria-keyshortcuts` announces the shortcut with the
  control.
- **WCAG 2.1.4 (character key shortcuts):**
  - Single-character shortcuts are off in fields by default.
  - **A page-level off switch ships in v1 (decided):** `<meta name="unmagic-hotkeys" content="off">`,
    or `document.documentElement.dataset.unmagicHotkeys = "off"`, disables
    every hotkey. A host settings screen can render that per user.
- **Keyboard:**

| Situation | Behaviour |
|---|---|
| Focus in a field, key without a modifier | Ignored (unless `in_fields`); the key types as normal |
| A modal `<dialog>` is open | Only hotkeys inside that dialog fire |
| The target is hidden (`checkVisibility()` false), `disabled`, `aria-disabled="true"` or `inert` | Ignored |
| Several visible targets share keys | The first in document order fires |
| IME composition (`isComposing`) or key repeat | Ignored |
| Match | `preventDefault()`, then `focus()` for fields and `click()` for everything else |

- **Focus:** a clicked control doesn't move focus unless its own action does
  (a dialog opens, a page visits). A focused field puts the caret at the end.

## Styling

_None._ The visible hint is `kbd` (see `kbd.md`). One coordination point: the
platform modifier glyph is rendered by `kbd` and swapped in the browser, as
described below.

## Behaviour (JavaScript)

`hotkey.js`: no custom element. Following `dialog.js`, it installs one
`keydown` listener on `document`, guarded by
`Symbol.for("unmagic-components.hotkey")`.

- **Matching:**
  - On each keydown, build the combination from `event.key` and its modifiers,
    mapping `mod` to `metaKey` on Apple platforms
    (`navigator.userAgentData?.platform ?? navigator.platform` matches
    `/Mac|iPhone|iPad/`) and to `ctrlKey` elsewhere.
  - Query `[data-unmagic-hotkey]` when the key is pressed, so there's no
    registry to keep in sync.
  - Before matching, check the off switch: the meta tag or
    `html[data-unmagic-hotkeys="off"]`. Both are read per keypress, so a morph
    or a script toggling them applies at once.
- **Platform glyphs for `kbd` (the client half of the shared rule):**
  - `kbd` renders both glyphs, with a server default from the User-Agent (see
    `kbd.md`).
  - On load, and on `turbo:load`, this module sets
    `document.documentElement.dataset.unmagicPlatform = "apple" | "other"`,
    using the same platform test as matching.
  - The `kbd` CSS lets that attribute override the server's guess. The server
    guess is right for most visitors, so there is normally no visible swap.
- **Events:** `unmagic-hotkey:trigger` is dispatched on the target (bubbles,
  cancelable) before acting. `preventDefault()` on it skips the click.

Turbo:
- **Cache:** there is no per-element state and no pending state, since there
  are no sequences, so there is nothing to reset.
- **Morph:** attributes are re-read when a key is pressed, so morphed changes
  apply at once.
- **Snapshot clones:** nothing is generated or bound per element.
- **Streamed content:** it works on arrival, because lookup happens per
  keypress on `document`.

Dependencies: none, and it doesn't need Turbo.

## I18n

None. Key names are rendered by `kbd` and its I18n keys.

## Specs

In a new `hotkey_spec.rb`:
- `hotkey("c", class: "x")` returns `class: "x"`, `data: { unmagic_hotkey: "c" }`
  and `aria: { keyshortcuts: "C" }`, and merges an existing `data:` hash.
- `mod+enter` maps to `aria-keyshortcuts="Control+Enter Meta+Enter"`, and adds
  `data-unmagic-hotkey-in-fields`.
- `in_fields: false` overrides the modifier default. `scope: :dialog` renders
  `data-unmagic-hotkey-scope`.
- `ArgumentError`:
  - for `"hyper+k"`, `""` and `"mod+w"`
  - for the sequence `"g i"`
  - for `in_fields: true` with `"c"`
  - for an unknown `scope:`
- Used with `link_to` and `form.submit`, the attributes land on the element.

## Preview

On `elements`: a toolbar where `/` focuses search, `c` opens a `dialog_tag`,
and `j` follows a link to a section. There is also a form where `mod+enter`
submits, and a toggle that sets `html[data-unmagic-hotkeys="off"]`.

Hand checks:
- Typing "c" in the search field types a "c".
- `mod+enter` works inside the textarea.
- With the dialog open, page shortcuts don't fire.
- Emulate a Mac and a non-Mac user agent to see the ⌘/Ctrl glyph swap in
  `kbd`.
- The `off` meta tag, and the preview's off toggle, disable all shortcuts.
- VoiceOver announces the shortcut.

## Future work

- **Sequences** such as `"g i"`. They need pending-key state with a timeout, a
  reset on `turbo:before-cache` and `turbo:visit`, a rule for partial matches,
  and `kbd`'s existing `sequence:` display. Out of v1 by decision.

## Open questions

- **Help overlay:** should the gem ship a `?` help dialog listing every
  `[data-unmagic-hotkey]` on the page? It would need a label per hotkey,
  probably the element's accessible name.
