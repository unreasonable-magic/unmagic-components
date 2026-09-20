# `spinner`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Loading Indicator" (gap source);
> `skeleton`; `FormBuilder#submit`'s "Saving…"

## Purpose

An indeterminate "working on it" mark for a short wait whose layout isn't
known in advance, or for a space too small to block out:
- inside a button while it acts
- beside "Checking DNS…"
- in a lazy Turbo Frame that loads one value

**When layout is known, use `skeleton` instead.** It keeps the page from
shifting, and is the gem's preferred loading state. The design principles
already route modal and table loading through skeletons, and this doesn't
change that.

## API

```erb
<%= spinner %>
<%= spinner "Checking DNS…", size: :small %>
<%= spinner size: :large, label: "Loading report" %>

<%# Inside a button whose own text already says what is happening %>
<button class="<%= button_classes %>" disabled>
  <%= spinner size: :small, label: false %> Verifying
</button>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `text` (positional) | String | `nil` | Visible text beside the ring; also its accessible label |
| `label:` | String or `false` | I18n "Loading…" | Spoken label when there is no visible text; `false` drops the status role |
| `size:` | `:small`, `:medium`, `:large` | `:medium` | 0.875rem, 1rem, 1.5rem. Validated |

- **Label precedence:** visible `text` is the label. Otherwise `label:` is
  visually hidden. `label: false` renders a decorative ring (`aria-hidden`)
  for use where the surrounding control is already announced.
- **Other options** go on the root `<span>`.

## Markup

```html
<span class="UnmagicSpinner UnmagicSpinner--medium" role="status">
  <svg class="UnmagicIcon UnmagicSpinner__ring" aria-hidden="true" …>…loader_circle…</svg>
  <span class="UnmagicVisuallyHidden">Loading…</span>
</span>

<span class="UnmagicSpinner UnmagicSpinner--small" role="status">
  <svg class="UnmagicIcon UnmagicSpinner__ring" aria-hidden="true">…</svg>
  <span class="UnmagicSpinner__text">Checking DNS…</span>
</span>

<svg class="UnmagicIcon UnmagicSpinner__ring UnmagicSpinner--small" aria-hidden="true">…</svg> <!-- label: false -->
```

- The ring is a new `loader_circle` glyph (Lucide `loader-circle`) added to
  `Icons::PATHS`. An open arc rotated by CSS stays one inline SVG, with no extra
  elements.

## Accessibility

- **Live region:** `role="status"` (polite), so inserting a spinner, such as a
  frame's placeholder, announces its label once. This matches
  `Skeleton.group`.
- **Decorative ring:** `label: false` removes the role and hides the ring. Use
  it only where the parent control already conveys the state.
- **Colour** isn't used for meaning; the label carries it.
- **Keyboard:** not interactive, nothing focusable.

## Styling

CSS section: `Spinners`, placed after `Skeleton`.

- **Elements and modifiers:** `UnmagicSpinner`, with `--small`, `--medium`,
  `--large`, `__ring` and `__text`.
- **Root:** `inline-flex`, `align-items: center`, `gap: 0.5rem`, 0.875rem text
  in `neutral-500`.
- **Ring:**
  - `currentColor`, so it inherits a button's colour.
  - Sized by the modifier, overriding `UnmagicIcon`'s 1rem.
  - `animation: unmagic-spin 0.8s linear infinite`.
- **Reduced motion (decided):**
  - The rotation stops.
  - Instead the ring pulses opacity slowly (`unmagic-spinner-pulse`, 2s,
    `ease-in-out`, between 1 and 0.4). Nothing moves, but it still signals that
    something is happening.
  - The principles allow an opacity change that doesn't move anything under
    reduced motion. A frozen arc would read as broken.
- Palette colours with `dark:` variants only.

## Small screens

Nothing to do: a ring is a ring. Inside a button it inherits the button's
44px target.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.spinner.loading` | "Loading…" |

## Specs

- **Defaults:** `spinner` → `span.UnmagicSpinner.UnmagicSpinner--medium`
  with `role="status"`, an `svg.UnmagicSpinner__ring[aria-hidden=true]`, and
  `.UnmagicVisuallyHidden` text "Loading…".
- **Visible text:** `spinner("Checking DNS…")` → `.UnmagicSpinner__text`
  with that text, and no visually hidden label.
- **`label: false`:** a bare `svg` with no `role` and no text.
- **Validation:** `size: :huge` raises `ArgumentError`
  (`unknown spinner size :huge`).
- **Passthrough:** `class:` and `data:` reach the root.

## Preview

`primitives` page (or `skeletons`, beside the loading states), `spinner`
section:
- the three sizes
- a spinner with text
- inside a primary and a default button (`label: false`)
- inside a card body

**Check by hand:**
- With OS reduced motion on, the ring pulses and doesn't rotate.
- Colour inherits inside the primary button.
- The dark theme.
- VoiceOver announces the label once on insertion (use a Turbo Frame demo).

## Open questions

- **Spinner on submit.** Should `FormBuilder#submit` show a spinner as well as
  "Saving…" while submitting? That would need CSS on
  `[aria-busy]` / `:disabled` and no JS. Proposal: no. The text already says it.
