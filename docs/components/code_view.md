# `code_view`

> Status: built
> Tier: 1 (no JS of its own; the copy button is `copy_button`'s `<unmagic-clipboard>`)
> Replaces or relates to: `copy_button`, `ai_chat_payload` (renders through it),
> `UnmagicProse` (shares its token colours), `panel` (the box to put one in)

## Purpose

A block of source to read or copy: a file as written, a tool's payload, a
backtrace, a command to paste. It colours the source with Rouge, wraps long
lines so nothing scrolls in two directions, and keeps a copy button in the
corner. It is **just the code**: no heading, no language chip, no tabs. Put it
in a `panel` for a switcher, or a `card` for a title.

It is not for a line of code in a sentence (`<code>` in prose) or for a form
control; `FormBuilder#text_area` with a monospace class is that.

## API

```erb
<%# The common case %>
<%= code_view @file.source, language: @file.language %>

<%# Numbered, capped, sideways, silent %>
<%= code_view backtrace, language: :plaintext, lines: true, max_height: "20rem", label: "Backtrace" %>
<%= code_view command, language: :shell, wrap: false, copy: false %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `source` (positional) | String | — | `nil` renders an empty block |
| `language:` | Symbol, String, Rouge lexer class or instance, `nil` | `nil` | A name Rouge knows (`:json`, `"ruby"`, `:erb`). Unknown or `nil` is plain text, uncoloured |
| `lines:` | Boolean | `false` | Numbers the lines. The numbers are drawn by CSS, so a copy leaves them behind |
| `wrap:` | Boolean | `true` | `false` keeps each line on one line and scrolls sideways |
| `max_height:` | CSS length or `nil` | `nil` | Past it the block scrolls. Sets the `--unmagic-code-view-max-height` knob |
| `copy:` | Boolean | `true` | The copy button |
| `label:` | String | I18n "Code" | The accessible name of a block that can scroll |
| `id:` | String | random | The wrapper's id; the `<code>` is `"#{id}_code"`, which the copy button reads |

- Other options go on the wrapper `<div>`. `style:` is merged with the knob.
- **Colouring goes through `config.highlight`**, `(source, language) -> [line, …]`,
  which defaults to `Highlight.lines`: Rouge, one `html_safe` string per line, each
  token in a `<span class="<shortname>">`. A host with another highlighter returns
  its own escaped lines.
- **`config.code_block`**, the seam a payload or prose block frames its code with,
  now defaults to a `code_view` with no copy button.

## Markup

```html
<div class="UnmagicCodeView UnmagicCodeView--copy" id="unmagic_code_view_1a2b3c4d">
  <pre class="UnmagicCodeView__pre"><code id="unmagic_code_view_1a2b3c4d_code" class="UnmagicCodeView__code language-json">{<span class="p">…</span></code></pre>
  <div class="UnmagicCodeView__copy">
    <unmagic-clipboard for="unmagic_code_view_1a2b3c4d_code" class="UnmagicClipboard" data-copied-label="Copied">
      <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicClipboard__button" aria-label="Copy" title="Copy">…</button>
      <span class="UnmagicVisuallyHidden" aria-live="polite"></span>
    </unmagic-clipboard>
  </div>
</div>
```

With `lines: true`, each line is `<span class="UnmagicCodeView__line">…\n</span>`:
a block holding its own newline, so the text a copy takes still has its line
breaks, and a wrapped continuation indents under its number.

With `max_height:` or `wrap: false` the `<pre>` gains `tabindex="0"
role="region" aria-label="Code"`.

A `<pre><code>` because that is what the platform, screen readers and every
Markdown renderer already mean by a code block.

## Accessibility

- A block that can scroll is a focusable, named region, so a keyboard can reach
  and scroll it. One that only wraps is not, since it would be a tab stop for
  nothing.
- The copy button is `copy_button`'s: an `aria-label`led icon button whose live
  region says "Copied". It is kept in the tab order even while visually faint,
  and `:focus-within` shows it.
- Line numbers are `::before` content, `user-select: none`, and absent from the
  accessibility tree's text.
- Colour is never the only carrier of meaning: an error token is also
  underlined, a comment italic.

## Styling

- Section **Code view** in `engine.css`: `UnmagicCodeView`, `__pre`, `__code`,
  `__line`, `__copy`; modifiers `--lines`, `--nowrap`, `--copy`.
- Section **Code tokens**: Rouge's short class names, grouped by meaning
  (punctuation, comment, keyword, name, declaration, variable, string, escape,
  number, error), inside `:where(.UnmagicCodeView, .UnmagicProse pre)` so
  every rule has zero specificity and a host's own theme wins by existing.
- Colours: surface `neutral-50`/`neutral-900`, border `neutral-200`/`neutral-800`,
  text `neutral-800`/`neutral-200`; tokens in red, blue, purple, cyan, green,
  sky and violet at `700`/`300`.
- Knob: `--unmagic-code-view-max-height`, read by `__pre`, set by `max_height:`
  or by a container for every code view inside it (`ai_chat_payload` does).
- Motion: the copy button fades in over 150ms; off under reduced motion.

## Small screens

- Lines wrap by default, so nothing scrolls sideways on a phone unless
  `wrap: false` asks for it.
- The copy button is always visible where nothing can hover
  (`@media (hover: none)`), and `copy_button`'s icon button meets the 44px
  target on coarse pointers.
- `max_height:` scrolls with the page's own momentum; the block deliberately
  doesn't contain overscroll, so a finger swiping over a short block still
  scrolls the page.

## Behaviour (JavaScript)

None of its own. The copy button needs `import "unmagic/components/clipboard"`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.code_view.label` | "Code" |

## Specs

`spec/unmagic/components/code_view_spec.rb`: `Highlight.lines` cuts tokens at
newlines, escapes, keeps empty lines and drops the trailing newline, finds
lexers by name, class and instance; the view's structure, the copy button's
`for`, numbered lines carrying their newlines, the region attributes and knob
when scrollable, passthrough options, the `highlight` seam, and `code_block`'s
new default.

## Preview

Browser page `code_view`: languages side by side, numbered and capped, sideways.
Check: hover and focus reveal the copy button; Tab reaches the capped block and
arrow keys scroll it; dark theme; a phone width wraps the long JSON.
