# `steps`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Stepper" (gap source); `dialog` (a wizard
> in the shared modal); a future onboarding checklist (`card` + `steps`)

## Purpose

Shows where someone is in a multi-page process: sign-up, import, checkout,
setup. Each step is complete, current, upcoming or in error, and completed
steps can link back.

It displays progress; it does not drive it. Each step is its own request, as
with `tabs href:`. For content switched in the page, use `tabs`.

## API

```erb
<%= steps do |steps| %>
  <% steps.step "Account", href: edit_account_path %>
  <% steps.step "Plan", description: "Pro, billed yearly", current: true %>
  <% steps.step "Payment" %>
<% end %>

<%= steps orientation: :vertical do |steps| %>
  <% steps.step "Connect GitHub", status: :complete %>
  <% steps.step "Import repositories", status: :error, description: "3 failed" %>
  <% steps.step "Invite your team", status: :upcoming %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `orientation:` | `:horizontal`, `:vertical` | `:horizontal` | Validated. Horizontal stacks vertically below 40rem |
| `label:` | String | I18n "Progress" | The `<nav>`'s `aria-label` |

**Step options:**

| Option | Values | Default | Notes |
|---|---|---|---|
| `current:` | Boolean | `false` | At most one step is current |
| `status:` | `:complete`, `:current`, `:upcoming`, `:error` | derived | Validated. Overrides derivation |
| `href:` | URL | `nil` | Renders the label as a link |
| `description:` | String | `nil` | A second line under the label |

- **Derived status:** steps before the `current: true` step are `:complete`,
  and steps after it are `:upcoming`. With no current step and no explicit
  statuses, all steps are `:upcoming`.
- **Validation in `render`:** two current steps, or `current: true` combined
  with a different `status:`, raise `ArgumentError`.
- **Other options** go on the `<nav>`.

## Markup

```html
<nav class="UnmagicSteps UnmagicSteps--horizontal" aria-label="Progress">
  <ol class="UnmagicSteps__list">
    <li class="UnmagicSteps__step" data-status="complete">
      <span class="UnmagicSteps__marker" aria-hidden="true"><svg class="UnmagicIcon">…check…</svg></span>
      <span class="UnmagicSteps__text">
        <a class="UnmagicSteps__label" href="/account/edit">Account</a>
        <span class="UnmagicVisuallyHidden">(completed)</span>
      </span>
    </li>
    <li class="UnmagicSteps__step" data-status="current" aria-current="step">
      <span class="UnmagicSteps__marker" aria-hidden="true">2</span>
      <span class="UnmagicSteps__text">
        <span class="UnmagicSteps__label">Plan</span>
        <span class="UnmagicSteps__description">Pro, billed yearly</span>
      </span>
    </li>
    <li class="UnmagicSteps__step" data-status="upcoming">
      <span class="UnmagicSteps__marker" aria-hidden="true">3</span>
      <span class="UnmagicSteps__text"><span class="UnmagicSteps__label">Payment</span></span>
    </li>
  </ol>
</nav>
```

- **Markers:**
  - complete: `check`
  - error: `circle_x`, from `Icons::TONE_ICONS[:bad]`
  - otherwise the step number, rendered by the server so it survives
    non-CSS rendering
- **Connector lines** are drawn by CSS between items, not as elements.

## Accessibility

- **Order:** an ordered list inside a labelled `<nav>`, so the list position
  ("3 items, 2 of 3") carries the order.
- **Current step:** `aria-current="step"`.
- **Status:** complete and error steps carry visually hidden text, "(completed)"
  and "(needs attention)", because colour and icon alone don't reach a screen
  reader.
- **Keyboard:** only linked steps are focusable, as ordinary links with a
  `:focus-visible` ring.

## Styling

CSS section: `Steps`.

- **Elements:** `UnmagicSteps`, with `--horizontal` and `--vertical`,
  `__list`, `__step`, `__marker`, `__text`, `__label` and `__description`.
- **State** comes from `[data-status=…]` and `[aria-current=step]`, with no
  state classes.
- **Marker:**
  - 1.5rem circle, 0.75rem weight-600 numerals.
  - upcoming: `--unmagic-surface` with a `--unmagic-border-strong` border
  - current: `--unmagic-accent` border, `--unmagic-text`
  - complete: filled `--unmagic-accent` with an `--unmagic-on-accent` check
  - error: `--unmagic-bad-surface` fill with `--unmagic-bad`
- **Label:** 0.875rem weight 500. Upcoming is `--unmagic-text-3`, others
  `--unmagic-text`. Description is 0.75rem `--unmagic-text-3`.
- **Connector:**
  - Horizontal: a 1px line (`::after` on each step but the last) in
    `--unmagic-border`, turning `--unmagic-accent` after complete steps.
  - Vertical: the same line running down beside the markers.
- **Responsive:** `@media (max-width: 40rem)` makes `--horizontal` lay out like
  `--vertical`.
- No new tokens and no motion.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.steps.label` | "Progress" |
| `unmagic.components.steps.complete` | "(completed)" |
| `unmagic.components.steps.error` | "(needs attention)" |

## Specs

- **Derived statuses:** with `current: true` on step 2 of 3, `data-status` is
  `complete`, `current`, `upcoming`, and only step 2 has
  `aria-current=step`.
- **Explicit statuses:** `status:` values render as given. The error step's
  marker contains an `svg` and the hidden "(needs attention)".
- **Markers:** numbers are "2" and "3". A complete step's marker has a check
  `svg` and no number.
- **Links:** `href:` renders `a.UnmagicSteps__label`, otherwise a `span`.
  `description:` renders `.UnmagicSteps__description`.
- **Validation:**
  - `orientation: :diagonal` and `status: :done` raise `ArgumentError`
  - two current steps raise
  - `current: true, status: :complete` raises
- **Passthrough:** `class:` and `aria-label` override on the `<nav>`.

## Preview

`primitives` page, `steps` section:
- horizontal, with step 2 current
- vertical, with an error step and descriptions
- `steps` inside a `card` as an onboarding checklist
- `steps` at the top of a `dialog` wizard, on the `dialogs` page

**Check by hand:** a narrow viewport switches to vertical, connector colours,
the dark theme, and link focus.

## Open questions

- **Onboarding checklist.** Does the Rails Blocks "onboarding checklist" need
  its own component, or is `card` + `steps orientation: :vertical` + a progress
  count enough? Proposal: document the composition and build nothing extra.
- **Progress bar.** A progress bar (`progress_bar value:, max:`) is a natural
  sibling but isn't in the gap list. Add it if wanted.
