# `ai_chat_plan`

> Status: built
> Tier: 1 (no JS of its own; `ai_chat.js` keeps a reader's choice)
> Relates to: [workspace](workspace.md), `card`, `steps`

## As built

Where the build differs from this note:

- The count reads `1/4`. Plan and workspace share `AIChat::Section` for the panel head.
- A section a person collapsed stays collapsed through broadcasts (see Behaviour). `open:` is the first
  render's state, not every render's.
- A waiting step shows its label as visible text: a warn badge after the title
  (see Accessibility).
- The head is quiet, because the panel sits beside the conversation: the title is
  a small uppercase label in muted text, the head glyph is `size-3.5` like the
  step glyphs, and the section pads `px-4 py-3`.

## Purpose

The checklist an agent is working through, redrawn where it stands each time it
ticks something off. A done step recedes and the one being worked stands up, so a
long plan reads as a position rather than as a list.

For a multi-step task the model lays out itself and rewrites as it goes. Not for
a wizard's progress — that is the planned [`steps`](../steps.md) component, which
is linear, finite and known in advance. A plan is none of those: it is rewritten
wholesale, it can grow, and a step can be parked on a person.

hooops and toybox both built this, both put it in a side panel, and both landed
on the same four states.

## API

```erb
<%= ai_chat_plan completed: plan.completed_count, total: plan.step_count do |p| %>
  <% plan.steps.each do |step| %>
    <% p.step step.title, state: step.status.to_sym %>
  <% end %>
<% end %>

<%# Always rendered, empty or not: a broadcast can only replace an element
    that is already on the page. %>
<%= ai_chat_plan id: "plan", empty: "Nothing planned yet." %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `title:` | string | "Plan" | |
| `completed:` / `total:` | integers | counted from the steps | The `3/7` reading |
| `open:` | boolean | `true` | It is what the side of the page is for. Until the person chooses |
| `empty:` | string | a default sentence | Shown when there are no steps |
| `collapsible:` | boolean | `true` | `false` renders a plain region, not a `<details>` |

- `p.step(title, state:)` — `:pending`, `:in_progress`, `:waiting`, `:completed`.
  Validated; raises `ArgumentError`.
- `p.step` also takes a block for a step with detail under it.
- With no steps it renders the empty sentence rather than nothing, for the
  broadcast reason above. This is the opposite of the gem's usual "renders
  nothing when empty" rule and the note says why.

`completed:`/`total:` are options rather than always derived because a plan can
be paged or truncated in a narrow panel, and a reading of `3/7` computed from
three visible steps would be wrong.

## Markup

```html
<details id="plan" class="UnmagicAIChatPlan" open>
  <summary class="UnmagicAIChatPlan__head">
    <svg aria-hidden="true">…</svg>
    <h2 class="UnmagicAIChatPlan__title">Plan</h2>
    <svg class="UnmagicAIChatPlan__chevron" aria-hidden="true">…</svg>
    <p class="UnmagicAIChatPlan__count">3/7</p>
  </summary>

  <ol class="UnmagicAIChatPlan__steps">
    <li class="UnmagicAIChatPlan__step" data-state="completed">
      <span class="UnmagicAIChatPlan__glyph">…<span class="UnmagicVisuallyHidden">Done</span></span>
      <span class="UnmagicAIChatPlan__label">Read the brief</span>
    </li>
  </ol>
</details>
```

An `<ol>`, because unlike a transcript these genuinely are a list of like things
in order.

## Accessibility

- `<details>`/`<summary>` for the disclosure, as everywhere else in this family.
- Each step's glyph is `aria-hidden` with a visually hidden state label —
  "Done", "In progress", "To do" — since the state is carried by a glyph, a
  colour and a strikethrough, none of which reach a screen reader.
- A waiting step's label, "Waiting on you", is visible instead: an amber
  `UnmagicBadge UnmagicBadge--warn` after the title, with a space between them so
  they read apart. It is the one step that won't move until the person acts, so
  it can't rest on a small amber glyph in a column of glyphs, and colour alone
  mustn't carry it. It is not also visually hidden, so it is read once.
- Every text colour is at least 4.5:1 on the panel's surface (white, or
  neutral-900 in dark). Only glyphs are fainter.
- The count is plain text in the summary, so it is read with the heading.
- The list is not a live region. A plan rewritten five times a turn, announced
  each time, is unusable; the steps' own states are what a reader checks.
- The heading level is `title_tag:` (default `h2`), so a panel with its own
  heading structure can fit it in.

## Styling

CSS section: **AI chat plans**.

- `.UnmagicAIChatPlan`, `__head`, `__title`, `__chevron`, `__count`, `__steps`,
  `__step`, `__glyph`, `__label`, `__waiting`

State from `[data-state]`, not classes:

```css
.UnmagicAIChatPlan__step[data-state="completed"] .UnmagicAIChatPlan__label {
  @apply text-neutral-500 line-through dark:text-neutral-400;
}
.UnmagicAIChatPlan__step[data-state="pending"]  .UnmagicAIChatPlan__label { @apply text-neutral-600 dark:text-neutral-300; }
.UnmagicAIChatPlan__step[data-state="in_progress"] .UnmagicAIChatPlan__label,
.UnmagicAIChatPlan__step[data-state="waiting"]     .UnmagicAIChatPlan__label { @apply font-medium text-neutral-900 dark:text-neutral-100; }
```

Glyph colours: completed green, in-progress neutral and spinning, waiting amber,
pending a faint neutral dashed circle. Waiting is the one that carries a colour,
for the reason the whole family uses amber: it is the only state that will not
move on its own.

Contrast, on white and on neutral-900 (WCAG, from Tailwind v4's oklch values):

| Text | Light | Dark |
|---|---|---|
| Title, count, empty sentence, detail, done step | neutral-500, 4.7:1 | neutral-400, 6.9:1 |
| To-do step | neutral-600, 7.8:1 | neutral-300, 12.1:1 |
| Waiting badge | amber-700 on amber-50, 4.9:1 | amber-400 on amber-400/10, 8.6:1 |
| In-progress and waiting step | neutral-900 | neutral-100 |

The spinner pulses instead of rotating under `prefers-reduced-motion: reduce`.

## Behaviour (JavaScript)

None of its own. A section given an `id:` keeps the person's own open or shut across broadcasts.
The `<details>` carries `data-ai-chat-disclosure="<id>"`, and `ai_chat.js`
remembers what the person last chose by clicking its summary. It applies that
choice to the element with the same id when a Turbo Stream replaces the section,
before it is painted, and it refuses a morph's reset of `open`. Until the person
chooses, and always without the script, the server's `open:` decides, as a plain
`<details>` would. The choices last until the page is loaded afresh.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.plan.title` | "Plan" |
| `unmagic.components.ai_chat.plan.empty` | "Nothing planned yet." |
| `unmagic.components.ai_chat.plan.pending` | "To do" |
| `unmagic.components.ai_chat.plan.in_progress` | "In progress" |
| `unmagic.components.ai_chat.plan.waiting` | "Waiting on you" |
| `unmagic.components.ai_chat.plan.completed` | "Done" |

## Specs

`spec/unmagic/components/ai_chat_plan_spec.rb`:

- Each state's `data-state`, glyph and visually hidden label.
- A waiting step's visible warn badge after the title, its translated label, and
  no visually hidden copy.
- The count from the steps, and an explicit `completed:`/`total:` overriding it.
- No count at all when there are no steps.
- The empty sentence when there are no steps, and the element still rendering.
- `collapsible: false` renders a region, not a `<details>`.
- `data-ai-chat-disclosure` carries the id, and is absent without one.
- `title_tag:` changing the heading level.
- `ArgumentError` for an unknown step state.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A plan with all four states present, an empty one, a long one
(twenty steps) inside a narrow panel, and a collapsed one.

By hand: keyboard open/close; dark theme; reduced motion. On the "Kept shut
across updates" example, collapse the plan and the workspace and send updates:
each stays shut, and one left alone follows the server. A morph refresh
(`Turbo.visit(location.href, { action: "replace" })`) keeps them too.

## Open questions

- Should a step be able to carry its own tool calls under it, so the plan and the
  transcript are one thing? Both applications keep them separate, and separate is
  simpler. Proposed: no, but `p.step` takes a block so the door is open.
