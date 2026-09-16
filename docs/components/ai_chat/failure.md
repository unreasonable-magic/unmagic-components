# `ai_chat_failure`

> Status: built
> Tier: 1 (no JS)
> Relates to: [message](message.md), [payload](payload.md), `callout`

## As built

Where the build differs from this note:

- `live: true` is built as described.

## Purpose

A turn that fell over, and what it fell over on. Without it the transcript simply
stops, and the page is left spinning at someone who is owed an answer.

The sentence at the top is for whoever asked. Everything under it is for whoever
is working on the assistant, which is why it is shut: a stack trace in the middle
of a conversation is noise right up until it is the thing you want.

Not `callout`, though it looks like one. A callout carries a message; this
carries a message, a cause, a disclosure of diagnostics, and a retry — and it has
to sit inside a turn that may also contain a page of real answer.

## API

```erb
<%= ai_chat_failure message.failure_message do |failure| %>
  <% failure.cause "#{e["class"]}: #{e["message"]}" %>
  <% failure.detail "Provider said", e["details"] %>
  <% failure.detail "Where it happened", e["backtrace"].join("\n"), language: :plaintext %>
  <% failure.retry { button_to "Retry", retry_path(chat) } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| (content) | string or block | required | The sentence for whoever asked |

Builder parts:

- `failure.cause(text)` — one line naming the error, in monospace, above the
  fold. The provider's own class and message are usually the part worth reading.
- `failure.detail(label, payload, language:)` — a row inside the disclosure,
  rendered through [payload](payload.md). Repeatable.
- `failure.retry { }` — the caller's own control.

With no parts it renders the sentence alone, which is what a turn that fell over
before anything was written down has to say.

A turn cut off at the context ceiling has a page of real answer in it and then
stops mid-sentence. Drawing only the failure over the top of that would throw
away the work to explain that the work didn't finish — so this component always
renders *below* the body, never in place of it, and the note for
[message](message.md) says so too.

The raw exception is never the sentence. All three applications persist and log
the exception and show the reader a friendly line, specific where they can name
the failure type and generic otherwise. The component takes the sentence; it does
not derive one.

## Markup

```html
<div class="UnmagicAIChatFailure">
  <div class="UnmagicAIChatFailure__head">
    <svg aria-hidden="true">…</svg>
    <div>
      <p class="UnmagicAIChatFailure__message">The assistant couldn't finish this reply.</p>
      <p class="UnmagicAIChatFailure__cause">Faraday::TimeoutError: execution expired</p>
    </div>
  </div>

  <details class="UnmagicAIChatFailure__details">
    <summary>Details</summary>
    <div>…payloads…</div>
  </details>

  <div class="UnmagicAIChatFailure__retry">…</div>
</div>
```

## Accessibility

- `role="alert"` on the container when it is streamed in, so the reader is told
  the turn failed rather than being left to notice the spinner stopped. Rendered
  on page load it is a plain region — an alert on every past failure in a
  reloaded transcript would announce all of them.
  The component takes `live: true` for the streamed case, defaulting to off,
  matching how `form_builder.rb` handles its error summary.
- The icon is `aria-hidden`; the tone is carried by the sentence, never by colour
  alone.
- `<details>` for the diagnostics, so the disclosure is native.
- The retry control is the caller's, and lands in the tab order after the
  disclosure.

## Styling

CSS section: **AI chat failures**.

- `.UnmagicAIChatFailure`, `__head`, `__message`, `__cause`, `__details`,
  `__retry`

`rounded-lg border border-red-200 bg-red-50` with
`dark:border-red-900/60 dark:bg-red-950/40`; the message in
`text-red-800 dark:text-red-300`; the cause in monospace at `text-xs` with
`break-words`, because a provider's message runs long and often contains a URL.

Red is the gem's "bad" tone, as `callout` uses it, so the two agree.

Motion: none.

## Behaviour (JavaScript)

None.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.failure.details` | "Details" |

The sentence and the labels are the caller's words, not the gem's.

## Specs

`spec/unmagic/components/ai_chat_failure_spec.rb`:

- The sentence renders from a positional argument and from a block.
- `cause` renders above the fold; `detail` renders inside the `<details>`.
- No `<details>` at all when there are no details.
- `live: true` adds `role="alert"`; the default does not.
- `retry` renders the caller's markup last.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A failure with only a sentence; one with a cause; one with two
details and a retry; and one inside a message that also has a page of prose above
it, which is the case the layout has to get right.

By hand: keyboard open the disclosure; dark theme; a very long provider message
(it must wrap).

## Open questions

- Should a failure inside a `<details>` be open when it is the only thing in the
  turn? Proposed: no. Shut is right even then — the sentence above the fold is
  the whole message for the person who asked.
