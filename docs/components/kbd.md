# `kbd`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "KBD & Hotkey" (gap source); `tooltip`
> (a hint that names a shortcut); `menu` items

## Purpose

Shows a key or key combination in text: "Press ⌘ K to search", a shortcut
beside a menu item, a cheat sheet. It only displays keys; binding a shortcut to
an action is `hotkey` (`hotkey.md`), which shares this note's key syntax and
its rule for showing `mod`.

## API

```erb
<%= kbd "Esc" %>
<%= kbd :cmd, "K" %>
<%= kbd :ctrl, :shift, "P" %>
<%= kbd :mod, "K" %>                  <%# ⌘ K on Apple platforms, Ctrl K elsewhere %>
<%= kbd hotkey: "mod+k" %>           <%# the same, from hotkey's key syntax %>
<%= kbd "G", "I", sequence: true %>   <%# press G, then I (display only) %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `*keys` | Strings or named keys | — | At least one, unless `hotkey:` is given; none raises `ArgumentError` |
| `hotkey:` | A `hotkey` key string | `nil` | Parsed with the same syntax as `hotkey` (`mod+shift+k`). Can't be combined with positional keys or `sequence:`, which raises `ArgumentError` |
| `sequence:` | Boolean | `false` | Keys pressed one after another, joined by "then". **Display only**: `hotkey` has no sequences in v1, so this is for documenting a host's own shortcuts |

- **Named keys** map to a glyph plus a spoken name:
  - `:mod` is the platform modifier: ⌘ "Command" on Apple platforms, Ctrl
    "Control" elsewhere. See "Platform modifier" below.
  - `:cmd` ⌘, `:ctrl` Ctrl, `:alt` ⌥, `:shift` ⇧, `:enter` ↵, `:esc` Esc,
    `:tab` Tab
  - `:up` ↑, `:down` ↓, `:left` ←, `:right` →, `:backspace` ⌫
  - They are listed in `Kbd::KEYS`. An unknown symbol raises
    `unknown kbd key :hyper (expected one of [...])`.
- **Platform modifier (decided; shared with `hotkey.md`).** `:mod` is shown as
  ⌘ on Apple platforms and Ctrl elsewhere. The decision is made in two places:
  1. **Server default.** The helper guesses from the request's User-Agent
     (`/Mac|iPhone|iPad/`) and writes `data-platform="apple"` or
     `data-platform="other"` on the outer `<kbd>`. Without a request, e.g. in a
     mailer, the default is `other`. This works with no JS, and is right for
     most visitors on first paint.
  2. **Client swap.** When `hotkey.js` is loaded, it sets
     `data-unmagic-platform` on `<html>` from the browser's own platform. CSS
     rules keyed on that attribute override the server's guess, so a spoofed
     or unusual User-Agent still ends up correct.

  Both glyphs are always rendered; CSS shows exactly one. `kbd` itself stays
  script-free.
- **String keys** render as given.
- **Other options** go on the outer `<kbd>`.

## Markup

```html
<kbd class="UnmagicKbd">
  <kbd class="UnmagicKbd__key" title="Command"><span aria-hidden="true">⌘</span><span class="UnmagicVisuallyHidden">Command</span></kbd>
  <kbd class="UnmagicKbd__key">K</kbd>
</kbd>

<!-- kbd :mod, "K" on a request from a Mac -->
<kbd class="UnmagicKbd" data-platform="apple">
  <kbd class="UnmagicKbd__key UnmagicKbd__mod UnmagicKbd__mod--apple" title="Command"><span aria-hidden="true">⌘</span><span class="UnmagicVisuallyHidden">Command</span></kbd>
  <kbd class="UnmagicKbd__key UnmagicKbd__mod UnmagicKbd__mod--other" title="Control">Ctrl<span class="UnmagicVisuallyHidden">Control</span></kbd>
  <kbd class="UnmagicKbd__key">K</kbd>
</kbd>

<kbd class="UnmagicKbd UnmagicKbd--sequence">
  <kbd class="UnmagicKbd__key">G</kbd>
  <span class="UnmagicKbd__joiner">then</span>
  <kbd class="UnmagicKbd__key">I</kbd>
</kbd>
```

- **Nested `<kbd>`** is the HTML-spec way to mark up a key combination: each
  inner `<kbd>` is one key.
- **Glyph keys** carry their spoken name, visually hidden, because screen
  readers pronounce "⌘" inconsistently (for example "place of interest sign").
- **Combinations** have no visible "+". The keys sit side by side, the common
  convention.

## Accessibility

- It's not a widget: no role, nothing focusable.
- Spoken output reads "Command K". A sequence reads "G then I".
- The hidden `:mod` variant is `display: none`, so it is out of the
  accessibility tree too. Only the visible glyph's name is read.
- `title` on each glyph key names it for sighted mouse users.

## Styling

CSS section: `Keys`.

- **Elements and modifiers:** `UnmagicKbd`, `__key`, `__joiner` and
  `--sequence`.
- **`UnmagicKbd`:** `inline-flex`, `gap: 0.25em`, `vertical-align: baseline`,
  and the host's `kbd` font rules reset.
- **`__key`:**
  - Sized in `em`, so it scales with the text around it: `min-width: 1.5em`,
    `padding: 0 0.375em`, `font: 500 0.75em/1.75 ui-monospace, monospace`,
    centred text.
  - `neutral-600`/`dark:neutral-400` on `neutral-50`/`dark:neutral-800/50`.
  - A 1px border in `neutral-200`/`dark:neutral-800`, with a 1px bottom box-shadow in
    `neutral-300`/`dark:neutral-700` for the key-cap edge.
  - Radius 0.25rem.
- **`__joiner`:** `neutral-500`, 0.75em.
- **`__mod`, `__mod--apple` and `__mod--other`** follow the platform modifier
  rule:
  - **Server default:**
    `.UnmagicKbd[data-platform="apple"] .UnmagicKbd__mod--other` and
    `.UnmagicKbd[data-platform="other"] .UnmagicKbd__mod--apple` are
    `display: none`.
  - **Client swap:** placed after the server-default rules at equal
    specificity, so they win.
    - `:root[data-unmagic-platform="apple"] .UnmagicKbd__mod--apple` is
      `display: inline-flex`, and the `--other` variant is `display: none`.
    - For `"other"` it is the reverse.
- **Inside a dark tooltip:** `.UnmagicTooltip__popup .UnmagicKbd__key` switches
  to a translucent surface, so keys stay legible on `neutral-900`/`dark:neutral-700`.
- Palette colours with `dark:` variants only, and no motion.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

Spoken key names, as `unmagic.components.kbd.<key>`:

| Key | Default |
|---|---|
| `unmagic.components.kbd.cmd` | "Command" |
| `unmagic.components.kbd.ctrl` | "Control" |
| `unmagic.components.kbd.alt` | "Option" |
| `unmagic.components.kbd.shift` | "Shift" |
| `unmagic.components.kbd.enter` | "Enter" |
| `unmagic.components.kbd.then` | "then" |

Plus one entry per remaining named key. `:mod` has no key of its own; its two
variants use `cmd` and `ctrl`.

## Specs

- **Combination:** `kbd(:cmd, "K")` → `kbd.UnmagicKbd > kbd.UnmagicKbd__key`
  count 2. The first key has `title="Command"`, the hidden text "Command", and
  an `aria-hidden` "⌘".
- **Sequence:** `kbd("G", "I", sequence: true)` → the `UnmagicKbd--sequence`
  class and one `.UnmagicKbd__joiner` with text "then".
- **Platform modifier:**
  - `kbd(:mod, "K")` renders both `.UnmagicKbd__mod--apple` and
    `.UnmagicKbd__mod--other`.
  - `data-platform` is `"apple"` for a Mac User-Agent and `"other"` for a
    Windows one. This needs `build_view` to take a `user_agent:`, which sets
    `HTTP_USER_AGENT`.
  - A missing User-Agent gives `"other"`.
- **`hotkey:`:**
  - `kbd(hotkey: "mod+shift+k")` renders the mod pair, then ⇧, then K.
  - `kbd("K", hotkey: "c")` raises `ArgumentError`, and so does
    `kbd(hotkey: "c", sequence: true)`.
- **Errors:** an unknown symbol raises `ArgumentError`, and so does
  `kbd()` with no keys.
- **Passthrough:** `class:` and `data:` land on the outer `<kbd>`.
- **Escaping:** string keys are escaped; `kbd("<b>")` renders the text, not an
  element.

## Preview

`primitives` page, `kbd` section:
- single keys and combinations in running text
- a sequence
- keys inside a `tooltip` hint
- keys at 0.75rem and at 1.25rem, to show the em scaling

**Check by hand:**
- Baseline alignment in a paragraph, the dark theme, and inside a tooltip.
- `:mod` shows ⌘ on a Mac and Ctrl on Windows, both without script and with
  `hotkey.js` loaded.
- With the User-Agent spoofed to Windows on a Mac, the glyph corrects itself
  once `hotkey.js` sets `data-unmagic-platform`.

## Open questions

- **Shortcut hints in menus.** Should `menu.link` accept `shortcut: [:cmd, "E"]`
  and render a right-aligned `kbd`? That is a small change to `menu.rb`.
