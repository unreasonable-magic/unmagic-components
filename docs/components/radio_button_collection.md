# `FormBuilder#radio_button_collection` and `#radio_button_field`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Radio" (gap source);
> `FormBuilder#check_box_collection` and `#check_box_field` (which it mirrors);
> `config.control_class`

## Purpose

Pick exactly one option from a short, visible set: a plan, a visibility level,
a notification frequency. It is Rails' `collection_radio_buttons` with the
labelling, grouping and spacing already done, the same way
`check_box_collection` does it for checkboxes. A `variant: :cards` layout
covers the "rich option" case, where each choice has a description.

For more than about seven options, use `form.select`. For several choices, use
`check_box_collection`.

**Also in scope (decided): checkbox parity.** `check_box_collection` gains the
same `legend:`, `hint_method:` and `variant: :cards` options in the same
change, so the two collections stay mirrors. Its existing call sites don't
change: every new option defaults to today's output.

## API

```erb
<%= form.radio_button_collection :visibility, Visibility.all, :key, :name, legend: "Who can see this?" %>

<%= form.radio_button_collection :plan, Plan.all, :id, :name,
      legend: "Plan", hint_method: :summary, variant: :cards, inline: true %>

<%# A single labelled radio, for a hand-built group %>
<%= form.radio_button_field :frequency, "daily", "Daily", hint: "One email each morning." %>
```

**`radio_button_collection(method, collection, value_method, text_method, **options)`**

| Option | Values | Default | Notes |
|---|---|---|---|
| `legend:` | String or `nil` | `nil` | Renders `<fieldset>` + `<legend>`; without it a `<div role="radiogroup">` |
| `hint_method:` | Symbol or callable | `nil` | A per-option hint under its label |
| `inline:` | Boolean | `false` | Options flow in a row, like `check_box_collection` |
| `variant:` | `:list`, `:cards` | `:list` | Validated |
| `required:` | Boolean | `false` | `required` on every radio, plus the label marker on the legend |

- **Other options** go on each `<input type="radio">`, as with
  `check_box_collection`.
- **`radio_button_field(method, value, label_text, hint: nil, **options)`**
  mirrors `check_box_field`.
- **The class on each radio** comes from `config.control_class.call(view, :radio)`,
  which returns `"UnmagicRadio"` by default. A host can return its own classes
  or `nil`. A caller's `class:` is merged after it.
- **Plain `form.radio_button` is not restyled.** It is Rails' own method and
  keeps Rails' behaviour, so a host decides when it opts in.
- **No legend:** without `legend:`, pass `"aria-label":`, or
  `"aria-labelledby":` pointing at a label you render.
- **`check_box_collection(method, collection, value_method, text_method, legend: nil, hint_method: nil, variant: :list, inline: false, **options)`**
  takes the same new options with the same meaning:
  - `legend:` wraps it in `fieldset.UnmagicChoiceGroup`.
  - `hint_method:` adds `UnmagicHint` per item.
  - `variant: :cards` adds the card modifiers, and it is validated against the
    same constant.
  - Without `legend:` it stays today's bare `div.UnmagicCheckList`, with no
    `role`; checkboxes need no group role.
  - Its checkboxes carry `UnmagicCheck` from `control_class.call(view, :check)`.
- **Errors:** an invalid attribute sets `aria-invalid="true"` on every radio.
  With a `legend:`, the error line renders under the group as `UnmagicError`,
  since a fieldset can't sit inside `field`'s label flow.

## Markup

```html
<fieldset class="UnmagicChoiceGroup">
  <legend class="UnmagicLabel">Plan <span class="UnmagicLabel__required">*</span></legend>
  <div class="UnmagicCheckList UnmagicCheckList--cards">
    <label class="UnmagicCheckField UnmagicCheckField--card">
      <input class="UnmagicRadio" type="radio" value="1" name="account[plan]" id="account_plan_1" required>
      <span class="UnmagicCheckField__text">
        <span class="UnmagicCheckField__label">Starter</span>
        <span class="UnmagicHint">For one person trying things out.</span>
      </span>
    </label>
    …
  </div>
  <p class="UnmagicError">Plan must be chosen</p>
</fieldset>
```

- **Rails parts:** Rails' `collection_radio_buttons` supplies the hidden empty
  value, names and ids. The builder block only lays out each item and adds the
  control class.
- **List variant:** drops the `--cards` modifiers, giving the same markup as a
  `check_box_collection` with `UnmagicCheck` swapped for `UnmagicRadio`.
- **Grouping:** `<fieldset>`/`<legend>` is the native radio group, so no ARIA is
  needed. The fallback is `role="radiogroup"` on the `div`.

## Accessibility

- **Group:** named by the legend, or by `aria-label` / `aria-labelledby` on the
  radiogroup `div`.
- **Keyboard:** native radio behaviour. Tab enters the group at the checked
  radio, and the arrow keys move and select.
- **Each option:** its wrapping `<label>` names it, and the hint is part of the
  label text.
- **Required and invalid:** `required` and `aria-invalid` sit on the inputs,
  and the error text follows the group.
- **Forced colours:** under `@media (forced-colors: active)` the drawn dot uses
  `CanvasText` / `Highlight`, so the checked state survives.

## Styling

CSS: in the `Forms` section, beside `UnmagicCheck` and `UnmagicSwitch`.

- **`UnmagicRadio`**, a real input drawn with CSS:
  - `appearance: none`, `1rem` square, `margin: 0.125rem 0 0` (to align with
    the first line of label text), radius 9999px, `flex-shrink: 0`.
  - A 1px `--unmagic-border-strong` border on `--unmagic-surface`.
  - `:checked`: border `--unmagic-accent`, with the inner dot
    `box-shadow: inset 0 0 0 0.25rem var(--unmagic-surface, …)` over an
    `--unmagic-accent` background.
  - `:focus-visible`: 2px `--unmagic-focus` outline with a 2px offset.
  - `:disabled`: opacity 0.5, `cursor: not-allowed`.
  - `[aria-invalid="true"]`: border `--unmagic-bad`.
- **`UnmagicChoiceGroup`:** resets the fieldset's `border`, `padding`, `margin`
  and `min-inline-size`, and adds `margin-bottom: 1rem` like `UnmagicField`.
  The legend has `margin-bottom: 0.375rem`.
- **`UnmagicCheckList--cards`:** a grid with
  `repeat(auto-fit, minmax(12rem, 1fr))` when `inline`, and a single column
  otherwise, with `gap: 0.5rem`.
- **`UnmagicCheckField--card`:**
  - `padding: 0.75rem 1rem`, a 1px `--unmagic-border` border, radius 0.5rem,
    background `--unmagic-surface`.
  - Hover: `--unmagic-border-strong`.
  - `:has(:checked)`: border `--unmagic-accent` plus a 1px inset ring of the
    same colour.
  - `:has(:disabled)`: opacity 0.55.
  - The card doesn't redraw focus; the radio's own ring shows inside it.
- **Motion:** a 150ms transition on border-colour and box-shadow, off under
  reduced motion.
- **Shared by checkboxes:** the `UnmagicChoiceGroup`, `--cards` and `--card`
  rules apply to `check_box_collection` unchanged.
- No new tokens.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

None.

## Specs

In `form_builder_spec.rb`:

- **Structure:**
  - `legend:` renders `fieldset.UnmagicChoiceGroup > legend.UnmagicLabel`
  - then `.UnmagicCheckList`
  - holding one `label.UnmagicCheckField` per item
  - each with `input.UnmagicRadio[type=radio]` and its text
- **Selection:** the radio matching the model's value is `checked`.
- **No legend:** renders `div.UnmagicCheckList[role=radiogroup]`, and
  `aria-label` passes through.
- **Hints:** `hint_method:` renders `.UnmagicHint` per item, from a symbol
  and from a lambda.
- **Variants:** `variant: :cards` adds `UnmagicCheckList--cards` and
  `UnmagicCheckField--card`. `inline: true` adds `UnmagicCheckList--inline`.
  `variant: :tiles` raises `ArgumentError`.
- **Required:** `required: true` marks every radio `required` and renders
  `.UnmagicLabel__required` in the legend.
- **Errors:** set `aria-invalid` on every radio and render `p.UnmagicError`
  after the list inside the fieldset.
- **Seam:** `config.control_class` returning `"radio"` changes each input's
  class, and returning `nil` leaves it with no class. A caller's `class:` is
  appended.
- **`radio_button_field`:** `label.UnmagicCheckField > input.UnmagicRadio[type=radio][value=daily]`
  plus the label and hint.
- **`check_box_collection` parity:**
  - With no new options, its output is identical to today (the existing spec
    still passes, plus `UnmagicCheck` on each input).
  - `legend:` renders `fieldset.UnmagicChoiceGroup > legend.UnmagicLabel`
    around `.UnmagicCheckList`.
  - `hint_method:` renders `.UnmagicHint` per item, from a symbol and from a
    lambda.
  - `variant: :cards` adds `UnmagicCheckList--cards` and
    `UnmagicCheckField--card`, and `variant: :tiles` raises `ArgumentError`.

## Preview

The `dialogs` edit-profile form gains a "Role" radio list. `primitives` gains
a plan picker using `variant: :cards, inline: true` with hints, a required
group showing an error, and a disabled option.

**Check by hand:**
- Arrow keys move within the group.
- A card click selects it.
- The checked dot and card ring show, and the focus ring shows.
- The dark theme: the dot's inner ring uses the surface colour.
- Forced-colours mode.
- Reset restores the initial choice.

## Open questions

- **Unnamed groups.** Should a group with neither `legend:` nor an ARIA name
  raise? Proposal: no raise, since the gem doesn't police accessibility
  elsewhere; document it instead.
