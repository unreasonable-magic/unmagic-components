# `ai_chat_branch_picker`

> Status: built
> Tier: 2 (small element)
> Relates to: [message](message.md), [action_bar](action_bar.md)

## As built

Where the build differs from this note:

- A disabled end has a `title` but no `aria-label`: it's a plain `<span>`, which may not be named.
- Focus restoration covers stream renders and Turbo visits, via a click on a step.

## Purpose

Moving between alternative versions of a turn: edit a question and the
conversation forks; run a reply again and there are two of it. The picker is the
`‹ 2/3 ›` that lets a reader walk between them.

assistant-ui's `BranchPickerPrimitive`. **None of the three applications has
branching**, and this is the note with the least evidence behind it, so it is
also the most conservative: the gem renders the control and knows nothing about
what a branch is.

For alternatives of one turn. Not for pagination, and not for a history of edits —
a branch is a live alternative, not a past version.

## API

```erb
<%= ai_chat_branch_picker index: 2, count: 3,
      previous: branch_path(message, -1), next: branch_path(message, +1) %>

<%# Inside an action bar, which is where it normally sits %>
<%= ai_chat_action_bar for: dom_id(message) do |bar| %>
  <% bar.control { ai_chat_branch_picker index: 2, count: 3, previous: …, next: … } %>
  <% bar.copy message.content %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `index:` | integer, 1-based | required | |
| `count:` | integer | required | |
| `previous:` / `next:` | path | `nil` | A `nil` end is a disabled control |
| `method:` | symbol | `:get` | `button_to` when non-GET |

- `count: 1` renders nothing. One version is not a branch, and a `1/1` on every
  turn in a transcript is noise on every turn in a transcript.
- `index:` outside `1..count` raises `ArgumentError`.

**The gem stays agnostic about what a branch is.** It renders counts and follows
links the host supplies; it holds no state, keeps no history, and makes no
request of its own. That is the only defensible position given no application
here has a branching model yet, and it is the open decision in the folder README.

## Markup

```html
<div class="UnmagicAIChatBranchPicker" role="group" aria-label="Version 2 of 3">
  <a class="UnmagicAIChatBranchPicker__step" href="…" aria-label="Previous version">‹</a>
  <span class="UnmagicAIChatBranchPicker__count" aria-hidden="true">2/3</span>
  <a class="UnmagicAIChatBranchPicker__step" href="…" aria-label="Next version">›</a>
</div>
```

An unavailable end renders a `<span>` with `aria-disabled="true"`, not a disabled
link — there is no such thing, and a disabled `<a>` is a lie to the keyboard.

## Accessibility

- `role="group"` with an `aria-label` carrying the whole reading ("Version 2 of
  3"), so a screen reader gets the position as a sentence rather than as the
  glyph-and-numbers the eye reads.
- The `2/3` itself is `aria-hidden`, since the group label already says it. Read
  twice, it is worse than not read at all.
- Chevrons are `aria-hidden`; each control has an `aria-label` and a matching
  `title`.
- Moving branches replaces the turn. The new turn must be announced, which is the
  transcript's `aria-live` region's job — so the replacement has to go through
  `upsert` into the transcript rather than a full-page navigation, and the note
  for [transcript](transcript.md) already sets that up.
- Focus after a move goes to the picker in the replaced turn, not to the top of
  the turn, so a reader can walk `› › ›` without re-finding the control. This is
  the one behaviour that needs script.

## Styling

CSS section: **AI chat branch pickers**.

- `.UnmagicAIChatBranchPicker`, `__step`, `__count`

`inline-flex items-center gap-0.5 text-xs text-neutral-500`, with the count in
`tabular-nums` so it does not jitter between `9/10` and `10/10`. Steps are small
`rounded` hit targets with the shared focus ring; a disabled one is
`opacity-40 cursor-default`.

Motion: none.

## Behaviour (JavaScript)

Focus restoration only, wired by delegation from `document`: on
`turbo:before-stream-render`, if focus is inside a picker whose turn is about to
be replaced, note it and restore to the same control afterwards. One small,
well-scoped behaviour, and the reason the component is Tier 2 rather than Tier 1.

Needs Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.branch_picker.label` | "Version %{index} of %{count}" |
| `unmagic.components.ai_chat.branch_picker.previous` | "Previous version" |
| `unmagic.components.ai_chat.branch_picker.next` | "Next version" |

## Specs

`spec/unmagic/components/ai_chat_branch_picker_spec.rb`:

- `count: 1` renders nothing.
- The group label reads "Version 2 of 3" and the count is `aria-hidden`.
- A `nil` end renders a span with `aria-disabled`, not a link.
- `method:` non-GET renders `button_to`.
- `ArgumentError` for an index outside the range, and for `count` below 1.
- Both controls carry `aria-label` and `title`.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. Pickers at the first, middle and last of three; one with ten
versions (to check the `tabular-nums`); one with `count: 1` (renders nothing);
and one inside an action bar under a real turn.

By hand: keyboard through the controls; confirm the disabled end is not
focusable; screen-reader the group label; dark theme.

## Open questions

- **What is a branch on the server?** The gem does not need to know, but the
  applications will, and the first one to grow branching should write that note
  before this component is wired to anything real. Candidates: a parent pointer
  on the message, or a version column with a shared branch key. This is open
  decision 3 in the folder README.
- Should editing a turn be part of this note or [action_bar](action_bar.md)?
  Proposed: the action bar owns the Edit control; this owns walking between what
  the edit created.
