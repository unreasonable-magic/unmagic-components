# `onboarding_checklist`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Onboarding Checklist" (gap source). Composes `card` and `steps` (steps.md), and uses a progress bar.

## Purpose

A "Get set up" card on a dashboard: a list of tasks, each marked complete,
current or upcoming, with a count ("2 of 5 done") and a progress bar. Each task
links to where the user does it. It is server-rendered from whatever the host
knows is done.

It isn't a wizard. The steps don't drive navigation; `steps` covers a
multi-page flow's indicator.

**Placement (decided):** core CSS. This is application UI, and it is mostly a
composition, so its own CSS is small.

## API

```erb
<%= onboarding_checklist title: "Get started", dismiss: dismiss_onboarding_path do |list| %>
  <% list.task "Create your first job", new_job_path, done: current_account.jobs.any?,
       description: "Describe the role and where it's based." %>
  <% list.task "Invite your team", new_invitation_path, done: current_account.invitations.any? %>
  <% list.task "Connect your calendar", calendar_settings_path, done: false %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `title:` | string | "Get started" (I18n) | The card title |
| `dismiss:` | URL or `nil` | none | Adds a `button_to` (DELETE) in the card actions |
| `collapse_done:` | boolean | `false` | Shows complete tasks as one "Show N completed" disclosure |
| `skeleton:` | boolean | `false` | The skeleton form, following `card`'s |

- **`list.task(name, url = nil, done:, description: nil)`.** The first task
  that isn't done is **current**, and the rest are **upcoming**. The host only
  says what is done. A `current:` override is allowed, for a task that's
  genuinely in progress.
- **When every task is done**, the card shows the `complete` block if given
  (`list.complete { "You're all set" }`), and otherwise renders nothing.
- **Other options** go on the card.

## Markup

This is `card` and `steps` output. The only new structure is the header
progress:

```html
<section class="UnmagicCard UnmagicOnboarding">
  <header class="UnmagicCard__header">
    <h2 class="UnmagicCard__title">Get started</h2>
    <div class="UnmagicCard__actions"><form …><button class="UnmagicButton UnmagicButton--ghost UnmagicButton--small">Dismiss</button></form></div>
  </header>
  <div class="UnmagicCard__body">
    <div class="UnmagicOnboarding__progress">
      <span class="UnmagicOnboarding__count">2 of 5 done</span>
      <progress class="UnmagicOnboarding__bar" max="5" value="2">2 of 5</progress>
    </div>
    <ol class="UnmagicSteps UnmagicSteps--vertical">…steps with a link per step…</ol>
  </div>
</section>
```

The step states (`aria-current="step"` for current, and a visually hidden
"Completed" for done) come from `steps`. Keep them consistent with steps.md.

## Accessibility

- A native `<progress>` with a text fallback. The visible count is its label
  (`aria-labelledby`).
- The task list is an ordered list, with state announced by `steps`.
- A done task keeps its link (to revisit it) but is de-emphasised.
- The dismiss button has a text label, so no icon-only button is needed.

## Styling

- **Section:** `Onboarding`.
- **Elements:** `__progress`, `__count`, `__bar`.
- **Progress bar:** `appearance: none`, a 0.375rem track in `neutral-100`/`dark:neutral-800`, and
  the fill in `neutral-900`/`dark:white` (styled via `::-webkit-progress-value` and
  `::-moz-progress-bar`). If a standalone `progress` component is built, this
  should use it instead.
- **Everything else** comes from the `Card` and `Steps` sections.

## Behaviour (JavaScript)

_None._ Dismiss is a `button_to`. The host answers it with a stream removing
the card, or a redirect.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.onboarding.title` | "Get started" |
| `unmagic.components.onboarding.progress` | "%{done} of %{total} done" |
| `unmagic.components.onboarding.dismiss` | "Dismiss" |
| `unmagic.components.onboarding.show_done` | "Show %{count} completed" |

## Specs

- Rendered as `section.UnmagicCard.UnmagicOnboarding`, with the title.
- `progress[max][value]` matches the done count.
- The first undone task is current; the ones before it are complete; the rest
  are upcoming (via the `steps` markup).
- `dismiss:` renders a DELETE form, and is omitted otherwise.
- All done with no `complete` block renders nothing; with the block, renders
  it.
- `collapse_done:` wraps done tasks in `<details>`.
- `skeleton: true` renders the skeleton.

## Preview

- **Page:** `primitives`, with three states: none done, partly done, and all
  done with a `complete` block.
- **Hand-check:** progress bar colours in dark mode, and a screen reader
  reading the progress and step states.

## Open questions

- Should a standalone `progress_bar` helper come first, and this use it?
- `steps` must support a link and a description per step; confirm this with
  steps.md.
