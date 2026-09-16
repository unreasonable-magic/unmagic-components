# `ai_chat_payload`

> Status: built
> Tier: 1 (no JS)
> Relates to: [tool_call](tool_call.md), [failure](failure.md), `UnmagicProse`'s code blocks

## As built

Where the build differs from this note:

- `copy: true` is built, as the open question proposed.
- The bordered box is the scroller, so a keyboard user focusing it can scroll it.

## Purpose

What went into a tool call or came back out of it, as something to read exactly
as it was written. A tool payload is read for the same reason a file is: to check
what actually happened against what was said about it.

Also for anything else in this family that has to show raw text — a backtrace, a
provider's error body, a skill's own instructions.

Not for prose. A tool that answers in Markdown should have that rendered, and the
component says so by taking a language.

## API

```erb
<%= ai_chat_payload call.arguments, label: "Asked" %>
<%= ai_chat_payload call.response, label: "Answered", duration: call.duration %>
<%= ai_chat_payload backtrace.join("\n"), label: "Where it happened", language: :plaintext %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | `nil` | The small caps heading above the block |
| `language:` | symbol | inferred | `:json`, `:plaintext`, or anything the host's highlighter knows |
| `duration:` | seconds | `nil` | A timing reading beside the label |

- The payload is a positional argument. A `Hash` or `Array` is pretty-printed as
  JSON; a `String` that parses as JSON is too; anything else is rendered as plain
  text rather than being mis-tokenised. All three applications wrote this same
  three-line rule.
- A `nil` payload renders nothing at all — not an em dash. An absent response is
  absent, and a dash would read as an empty one.

## Markup

```html
<div class="UnmagicAIChatPayload">
  <div class="UnmagicAIChatPayload__head">
    <span class="UnmagicAIChatPayload__label">Answered</span>
    <span class="UnmagicAIChatPayload__timing">…</span>
  </div>
  <pre class="UnmagicAIChatPayload__code"><code>…</code></pre>
</div>
```

## Accessibility

- The label is a plain `<span>`, not a heading: a tool call's disclosure is not a
  document outline, and four `<h4>`s per call would wreck the page's.
- The block is `tabindex="0"` so a keyboard user can scroll it, with an
  accessible name from the label — a scrollable region that cannot be reached by
  keyboard is a trap in reverse.
- Highlighting is decoration. The tokens carry no meaning colour alone conveys,
  and the text is real text for find-in-page and copy.

## Styling

CSS section: **AI chat payloads**.

- `.UnmagicAIChatPayload`, `__head`, `__label`, `__timing`, `__code`

The block scrolls rather than growing without limit, and long lines wrap rather
than running off sideways: `max-h-64 overflow-auto whitespace-pre-wrap
break-words`, plus `overscroll-contain` so that scroll doesn't chain to the page.
One line of either can be a whole page — a URL, a digest, a base64 blob.

Label: `text-[10px] font-medium uppercase tracking-wide text-neutral-500`.
Surface: `bg-white dark:bg-neutral-950`, `rounded-md`, `font-mono text-xs`.

## Behaviour (JavaScript)

None.

## The highlighting seam

All three applications highlight with Rouge, and the gem depends on no
highlighter. A new callable on `Configuration`:

```ruby
# The rendered code block. Called with (view, source, language); returns markup.
# The default is an unhighlighted <pre><code>, escaped.
config.code_block = ->(view, source, language) { view.highlight_code(source, language:) }
```

This is the same shape as `submit_class` and `control_class`, and it is the
fourth seam in the gem, so it is not a new idea — just a new instance.

`UnmagicProse`'s fenced code blocks go through the same seam, so a tool payload
and a code block in a reply are coloured by the same gear. That is what all three
applications do and it is the reason to put the seam on `Configuration` rather
than as an option on this component.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.payload.took` | "Took" |

The durations themselves use the `unmagic.components.elapsed.*` keys, so a
payload's timing and a tool call's clock read identically.

## Specs

`spec/unmagic/components/ai_chat_payload_spec.rb`:

- A Hash and an Array pretty-print as JSON with `language: :json` inferred.
- A JSON string parses and pretty-prints; a non-JSON string stays plain text.
- `nil` renders nothing.
- `label:` and `duration:` render in the head; neither renders an empty head.
- The block is `tabindex="0"` with an accessible name.
- `config.code_block` is called with the right arguments and its markup used.
- Configuration is reset between examples, so the seam spec needs no cleanup.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A JSON payload, a plain-text one, a very long single line, a
200-line one (to see the scroll and the overscroll containment), and one with a
label and duration.

By hand: keyboard-scroll the block; confirm the page does not scroll when the
block reaches its end; dark theme.

## Open questions

- Should the block get a copy button? `copy_button` already exists and this is
  exactly its case. Proposed: yes, behind `copy: true`, defaulting to off — a
  copy button on every one of five payloads per call is a lot of chrome for
  something rarely wanted.
