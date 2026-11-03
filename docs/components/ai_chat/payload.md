# `ai_chat_payload`

> Status: built
> Tier: 1 (no JS)
> A child of: [tool_call](tool_call.md), [failure](failure.md)

## Purpose

What went into a tool call or came back out of it, as something to read exactly
as it was written. A tool payload is read for the same reason a file is: to check
what actually happened against what was said about it. A failure's detail rows
(a provider's error body, a backtrace) are the same thing in the same place.

A payload is a child, like a list item: it lives in the fold of a tool call or a
failure, and has no look of its own anywhere else. The helper exists so a host
can render one on its own to stream into a running call, and so the two parents
share one renderer. `tool.asked`, `tool.answered` and `failure.detail` are the
usual way to get one.

Not for prose. A tool that answers in Markdown should have that rendered, and the
component says so by taking a language.

## API

```erb
<%# Inside a tool call, the usual way %>
<%= ai_chat_tool_call name: call.name, state: call.state do |tool| %>
  <% tool.asked call.arguments %>
  <% tool.answered call.response, duration: call.duration %>
<% end %>

<%# On its own, to stream into a call's fold %>
<%= ai_chat_payload call.response, label: "Answered", duration: call.duration %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | `nil` | The caption, and the region's accessible name |
| `language:` | symbol | inferred | `:json`, `:plaintext`, or anything the host's highlighter knows |
| `duration:` | seconds | `nil` | A timing reading beside the caption |
| `copy:` | boolean | `false` | A copy button beside the caption |

- The payload is a positional argument. A `Hash` or `Array` is pretty-printed as
  JSON; a `String` that parses as JSON is too; anything else is rendered as plain
  text rather than being mis-tokenised. All three applications wrote this same
  three-line rule.
- A `nil` payload renders nothing at all — not an em dash. An absent response is
  absent, and a dash would read as an empty one.

## Markup

A captioned figure over a scrollable block. The caption is what the payload is,
with the duration as a `<time>` whose datetime is the duration itself.

```html
<figure>
  <figcaption>Answered <time datetime="PT0.64S">640ms</time></figcaption>
  <div role="region" tabindex="0" aria-label="Answered">
    <pre><code>…</code></pre>
  </div>
</figure>
```

`<figure>` and `<figcaption>` because that is what a captioned block of content
is. The block inside the region is whatever `config.code_block` returns, which
by default is a `code_view`.

## Accessibility

- The caption is a `<figcaption>`, not a heading: a tool call's fold is not a
  document outline, and four `<h4>`s per call would wreck the page's.
- The block is a `role="region"` with `tabindex="0"`, named by the caption, so
  a keyboard user can reach and scroll it — a scrollable region that cannot be
  reached by keyboard is a trap in reverse.
- Highlighting is decoration. The tokens carry no meaning colour alone conveys,
  and the text is real text for find-in-page and copy.

## Styling

CSS section: **AI chat payloads**.

A figure is styled by the fold that holds it, `unmagic-tool-call > details` or
a failure's body, and nowhere else. Nothing is styled by class.

The block scrolls rather than growing without limit, and long lines wrap rather
than running off sideways: `max-h-64 overflow-auto whitespace-pre-wrap
break-words`. It doesn't contain overscroll: Chrome applies that to a short
payload that isn't overflowing, and a finger swiping over one then couldn't
scroll the page. One line of either can be a whole page — a URL, a digest, a
base64 blob.

Caption: `text-[10px] font-medium uppercase tracking-wide text-neutral-500`,
with the time and copy button pushed to the right. Surface: `bg-white
dark:bg-neutral-950`, `rounded-md`, `font-mono text-xs`.

## Behaviour (JavaScript)

None.

## The highlighting seam

All three applications highlight with Rouge, and the gem depends on no
highlighter. `config.code_block` is called with `(view, source, language)` and
returns the markup for the block; the default is a `code_view` without a copy
button. `UnmagicProse`'s fenced code blocks go through the same seam, so a tool
payload and a code block in a reply are coloured by the same gear.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.payload.took` | "Took" |
| `unmagic.components.ai_chat.payload.label` | "Payload" |

The durations themselves use the `unmagic.components.elapsed.*` keys, so a
payload's timing and a tool call's clock read identically.

## Specs

In `spec/unmagic/components/ai_chat_tool_call_spec.rb`:

- A Hash and an Array pretty-print as JSON with `language: :json` inferred.
- A JSON string parses and pretty-prints; a non-JSON string stays plain text.
- `nil` renders nothing; no label renders no caption, and the region is still
  named.
- The figure, caption, time and region, with the caption as the region's name.
- `copy:` adds a copy button; passthrough `class:` and attributes.

## Preview

On the tool call page, "What went in and what came back": a JSON payload with a
duration and a copy button, and a long plain-text one that scrolls, both inside
an open fold. The failure page shows detail rows.

By hand: keyboard-scroll the block; confirm the page does not scroll when the
block reaches its end; dark theme.

## Open questions

None.
