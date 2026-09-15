# `emoji_picker`

> Status: draft
> Tier: 3 (large)
> Replaces or relates to: the gap source is Rails Blocks "Emoji Picker". Relates to `popover.md` (the panel it opens in), `combobox.md` (filtering, if searchable) and `autogrow.js` (inserting into a textarea).

## Decision: no bundled emoji data; build only a curated picker

**Decided: the gem ships the curated-only picker, with no bundled emoji
dataset and no full "every emoji" picker. It is a picker over a short,
host-provided set, for reactions and status icons.**

Why no bundled data:
- **Size.** The full Unicode set has about 3,700 emoji, or several thousand
  with skin-tone variants. A usable picker needs names and search keywords from
  CLDR annotations, which come to hundreds of kilobytes of JSON. And the names
  are per-locale, while this gem has no locale files (principle "Words").
- **Churn.** Unicode adds emoji every year, and operating system fonts lag, so
  a bundled set renders tofu (boxes) for recent emoji on older devices. Keeping
  that current would make gem releases track the Unicode calendar.
- **Principle 3.** The gem would take on a data dependency, and principle 7
  (small surface) weighs against it.
- **The full picker is a solved problem.** Apps that want one can use the
  operating system's own picker (⌃⌘Space, Win+.), or a dedicated library.

Most application UI needs a **handful** of emoji: 👍 🎉 ❤️ 😄 👀 🚀 on a
comment, or a status icon from a curated list. Those can be drawn from Ruby
with names the host provides. That smallest version is designed below.

## Purpose

This chooses one emoji from a curated set: adding a reaction to a comment, or
setting a status icon. It is **not** a general emoji keyboard, and it isn't
for inserting emoji into prose (the operating system picker does that better).

## API

```erb
<%# Reaction: posts the choice %>
<%= emoji_picker url: comment_reactions_path(comment), param: :emoji,
      emojis: { "👍" => "Thumbs up", "🎉" => "Party", "❤️" => "Heart", "👀" => "Eyes" } %>

<%# Status icon as a form value %>
<%= form.field :status_emoji, "Status", as: :emoji_picker, emojis: Status::EMOJIS, clear: true %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `emojis:` | `{ emoji => name }` hash | required | The names are required: they are the accessible labels |
| `url:` | URL | `nil` | Posts `param` (a `button_to` per emoji) |
| `param:` | symbol | `:emoji` | With `url:` |
| `label:` | string | "Add reaction" | Trigger button label |
| `columns:` | integer | `8` | Grid width, used for Up/Down |
| `clear:` | boolean | `false` | Form mode: a "None" choice |

- **`url:` or form mode, not both.**
  - `url:` renders each emoji as a `button_to`, so it works without script and
    `turbo_stream` responses work.
  - Form mode (`FormBuilder#emoji_picker`) renders a hidden input, and the
    trigger shows the current emoji.
- **Validation:**
  - an empty `emojis:` raises `ArgumentError`
  - more than 64 entries raises `ArgumentError`, because a larger set needs
    search and belongs to a bigger picker
- **Other options** go on `<unmagic-emoji-picker>`.

## Markup

```html
<unmagic-emoji-picker class="UnmagicEmojiPicker" columns="8">
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicEmojiPicker__trigger"
          aria-haspopup="true" aria-expanded="false" aria-controls="reactions_12_panel"
          aria-label="Add reaction" title="Add reaction">…smile-plus icon…</button>
  <div id="reactions_12_panel" class="UnmagicEmojiPicker__panel" popover>
    <div class="UnmagicEmojiPicker__grid" role="group" aria-label="Reactions" style="--columns: 8">
      <form class="UnmagicEmojiPicker__form" method="post" action="/comments/12/reactions">
        <input type="hidden" name="emoji" value="👍">
        <button type="submit" class="UnmagicEmojiPicker__emoji" aria-label="Thumbs up" title="Thumbs up" tabindex="0">👍</button>
      </form>
      …
    </div>
  </div>
</unmagic-emoji-picker>
```

- **The panel is a native `popover`** (auto). The trigger toggles it via
  `popovertarget` in the server-rendered markup, so it opens without this
  script. Light-dismiss and Escape are native, and it sits in the top layer.
  If `popover.md` settles on a shared popover component, this renders through
  it.
- **Each emoji is a real button**, with its name as `aria-label` and `title`,
  so its meaning never depends on the glyph rendering.

## Accessibility

- **Trigger:** `aria-expanded` is kept true by the popover `toggle` event; its
  label is the action ("Add reaction").
- **Grid:**
  - A labelled `role="group"` of buttons with a roving tabindex: only one
    emoji is in the tab order, so Tab leaves the grid.
  - It is not `role="grid"`: there are no rows, headers or cells to navigate,
    and a group of buttons is honest about what it is.
- **Focus:** opening focuses the current (form mode) or first emoji; closing
  returns focus to the trigger (native popover behaviour with
  `popovertarget`).
- **Announcement:** in form mode, choosing updates the trigger's label to
  "Status: Party". In `url:` mode the response is the feedback.

| Key | Does |
|---|---|
| Enter / Space on trigger | Opens the panel |
| Left / Right | Previous / next emoji (wraps) |
| Up / Down | Moves by `columns` |
| Home / End | First / last emoji |
| Enter / Space on emoji | Chooses it: submits (`url:`) or sets the value and closes |
| Escape | Closes, focus returns to the trigger (native) |
| Tab | Leaves the grid; the auto popover closes when focus leaves |

## Styling

Section `/* Emoji pickers */`.

- **Elements:** `UnmagicEmojiPicker`, `__trigger`, `__panel`, `__grid`,
  `__form` (`display: contents`, like `UnmagicMenu__form`), `__emoji`,
  `__clear`.
- **Grid:** `display: grid; grid-template-columns: repeat(var(--columns), 2rem)`.
- **Emoji buttons:** 2rem squares, font-size 1.25rem, with no host font
  override. The font family uses the platform emoji fonts
  (`"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"`) after
  `inherit`.
- **State:** `__emoji[aria-pressed="true"]` (form mode's current value) uses
  `surface-3` and a ring. `:hover` and `:focus-visible` use `hover` and the
  focus outline.
- **Panel:** the menu panel's surface, border, radius and shadow; popover UA
  defaults are reset, as `UnmagicTooltip__popup` does.
- **Tokens:** no new ones.
- **Motion:** none.

## Behaviour (JavaScript)

`emoji_picker.js` defines `<unmagic-emoji-picker>`. It adds only what
`popover` and buttons lack.

- **Placement:** the panel is positioned below the trigger when it opens
  (flipping above when there's no room), using the same code as
  `tooltip.js`'s `#position`, or a shared placement module if one exists by
  then.
- **Keyboard:** arrow, Home and End navigation with the roving tabindex, and
  focus to the current or first emoji on `toggle` open.
- **Form mode:** choosing writes the hidden input, updates the trigger's
  glyph, `aria-label` and `aria-pressed`, dispatches `input` and `change`, and
  calls `hidePopover()`. Form `reset` restores the server value.
- **`url:` mode:** no JS is involved in submitting. The element only closes
  the panel on `submit`.
- **Events:** `unmagic-emoji-picker:choose`, with `detail: { emoji, name }`.
- **Turbo:**
  - `turbo:before-cache`: `hidePopover()` and reset the roving tabindex, so
    snapshots never show it open.
  - `turbo:morph`: the markup returns to the server's state. If the panel was
    open, the morph may close it, which is acceptable for a transient panel.
  - Snapshot clones: nothing is generated. The tabindex is re-derived on
    connect.
  - Streamed in: a comment appended by a stream carries its own picker, with
    listeners set in the constructor. No document scan.
- **Dependencies:** none. Turbo is optional; it is only needed for stream
  responses in `url:` mode.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.emoji_picker.label` | "Add reaction" |
| `unmagic.components.emoji_picker.group` | "Reactions" |
| `unmagic.components.emoji_picker.none` | "None" |
| `unmagic.components.emoji_picker.current` | "%{label}: %{name}" |

Emoji names come from the host's `emojis:` hash, so the host translates them.

## Specs

`spec/unmagic/components/emoji_picker_spec.rb`:

- **Trigger:** `aria-controls` matches the panel id, `popovertarget`,
  `aria-haspopup`, and the label default and override.
- **`url:` mode:** a form per emoji posting `param` to `url`; buttons named
  from the hash.
- **Form mode:** the hidden input with the value, `aria-pressed` on the current
  emoji, the "None" button with `clear: true`, and the trigger showing the
  current glyph.
- **`--columns`** and the `columns` attribute.
- **`ArgumentError`:** empty `emojis:`, more than 64 emojis, and both `url:`
  and form mode.

## Preview

On `elements`:
- a comment card with reactions posting to a preview action that answers with
  `turbo_stream.toast`
- a status-emoji form field with `clear: true`

Check by hand:
- Arrow keys across rows; Escape returns focus.
- Works inside a `card` with `overflow: hidden` (top layer).
- Disabling JS: the panel still opens via `popovertarget`, and a reaction still
  posts.
- Turbo back shows the panel closed; VoiceOver reads the names.
- Dark theme.

## Open questions

1. **Should reactions (counts plus "you reacted" state) be a separate
   component** that uses this picker? That is likely wanted alongside it.
2. **Is the limit of 64 emojis before requiring search the right line?**

## Comparison with native and operating system pickers

There is no native emoji `<input>`. The native alternatives are typing into a
text field, where the operating system picker (⌃⌘Space on macOS, Win+. on
Windows, the emoji key on mobile keyboards) inserts emoji, and the host's own
buttons.

| | Operating system emoji picker + text field | Full in-page picker with bundled data (replace) | Curated picker (this note) |
|---|---|---|---|
| **What users gain** | Every emoji, skin tones, recent choices, search in the user's language | Discoverable in the page, the same on every platform, can be tied to an action (reactions) | One-click reactions or status from the app's own set, with no typing and no hidden shortcut |
| **Accessibility** | The operating system's own; screen-reader tested | High cost: a large 2-D grid, category tabs, a search combobox, and a name for every one of 3,700 emoji | Low cost: a small named button group with a roving tabindex |
| **Mobile** | The emoji keyboard, which is the best available | A heavy scrolling grid that competes with the keyboard | A small popover of large targets |
| **Locale** | Names and search in the user's operating system language | Needs per-locale CLDR names and keywords that the gem would ship and update | Names come from the host's hash, so they translate like any other string |
| **JS and data** | None | Hundreds of KB of data, a yearly Unicode update, tofu on older devices | About 2 KB; no data |

**Decision (as recommended):**
- **Skip** the full picker. It is clearly worse than the operating system
  picker on every axis except in-page discoverability, and it carries a data
  burden against principles 3 and 7.
- **Build only the curated picker**, which does something neither the native
  input nor the operating system picker can: choose from an app-defined set as
  a single action.
