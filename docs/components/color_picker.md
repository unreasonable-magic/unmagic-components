# `color_picker`

> Status: draft
> Tier: 3 (large)
> Replaces or relates to: the gap source is Rails Blocks "Color Picker". Relates to `FormBuilder#field` and `radio_button_collection` (swatch semantics).

## Decision: enhance `<input type="color">`

**Recommendation: build a small enhancement around the native colour input,
with a hex text field and optional named swatches. Do not draw a custom
saturation and hue canvas.**

Why:
- **Principle 2.** The native input opens the operating system's colour
  chooser, which has an eyedropper, saved colours and accessibility the gem
  couldn't match.
- **A custom 2-D canvas has no good accessible pattern.** Slider-based
  alternatives multiply the keyboard surface.
- **What apps actually need** is three things:
  1. choose from a **brand palette** (label colours, avatar colours)
  2. **paste or type a hex** value
  3. occasionally anything else

Revisit a custom picker only for alpha (opacity) or colour spaces beyond sRGB
hex, which the native input doesn't cover consistently (see Open questions).

## Purpose

This picks a colour for something the user owns: a label, a calendar or a
theme accent. It is **not** a design tool, and it doesn't handle gradients or
opacity.

## API

```erb
<%= form.field :colour, "Colour", as: :color_picker,
      swatches: { "Red" => "#ef4444", "Amber" => "#f59e0b", "Green" => "#22c55e", "Blue" => "#3b82f6" } %>

<%# Swatches only: no custom colour %>
<%= form.color_picker :colour, swatches: Label::COLOURS, custom: false %>

<%= color_picker_tag "accent", "#3b82f6" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `swatches:` | `{ name => hex }` hash, or `[]` | `{}` | The names are required, because colour isn't a name |
| `custom:` | boolean | `true` | Shows the native input and hex field |

- **The submitted value** is a lowercase `#rrggbb` from the hex text input.
- **A blank value** renders no swatch pressed, an empty hex field and a native
  input at `#000000` (it can't be empty), marked as not yet chosen.
- **Validation:** hex values in `swatches:` are checked, and a malformed one
  raises `ArgumentError`. The record's own value is the host's to validate;
  the README gives a `format:` validation example.
- **Options:**
  - `required:` and `aria-invalid` go on the hex input.
  - Other options go on `<unmagic-color-picker>`.

## Markup

```html
<unmagic-color-picker class="UnmagicColorPicker">
  <div class="UnmagicColorPicker__swatches" role="group" aria-label="Swatches">
    <button type="button" class="UnmagicColorPicker__swatch" style="--swatch: #ef4444"
            data-value="#ef4444" aria-pressed="true" aria-label="Red">
      <svg class="UnmagicIcon UnmagicColorPicker__check" aria-hidden="true">…check…</svg>
    </button>
    <button type="button" class="UnmagicColorPicker__swatch" style="--swatch: #3b82f6"
            data-value="#3b82f6" aria-pressed="false" aria-label="Blue">…</button>
  </div>
  <div class="UnmagicColorPicker__custom">
    <input type="color" class="UnmagicColorPicker__native" value="#ef4444" aria-label="Custom colour" tabindex="-1">
    <input type="text" id="label_colour" name="label[colour]" class="UnmagicColorPicker__hex"
           value="#ef4444" pattern="#[0-9a-fA-F]{6}" maxlength="7" spellcheck="false" autocomplete="off">
  </div>
</unmagic-color-picker>
```

- **The named hex text input is the source of truth.** Without script a user
  can still type a value and the form submits it.
- **The native colour input has no name.** The element keeps it in sync, and it
  is `tabindex="-1"` because the hex field is the keyboard path (see
  Accessibility).
- **Swatches** are toggle buttons (`aria-pressed`), not radios. Radios would
  need a `name`, and a second submitted control would compete with the hex
  field.

## Accessibility

- **Every swatch has a name** (`aria-label` from the `swatches:` key), so a
  screen reader hears "Red, pressed", never a bare hex. The pressed swatch
  shows a check icon, so meaning is never colour alone.
- **Keyboard:**
  - Swatches are ordinary buttons in the tab order.
  - The hex field takes typing and paste.
  - The native picker is reachable by pointer; keyboard users set a custom
    colour through the hex field, which is also how the native picker's result
    is shown.
- **Check contrast:** the check icon's colour is picked from the swatch's
  luminance (white or `neutral-900`), computed in Ruby, so it is correct before
  script.
- **Invalid hex:** the native `pattern` reports it on submit, and
  `aria-invalid` comes from `field` errors.

| Key | Does |
|---|---|
| Tab | Each swatch, then the hex field |
| Enter / Space | On a swatch: chooses it (`aria-pressed`) and writes the hex |
| Typing a valid `#rrggbb` | Updates the native input, and presses the matching swatch if there is one |

## Styling

Section `/* Colour pickers */`.

- **Elements:** `UnmagicColorPicker`, `__swatches`, `__swatch`, `__check`,
  `__custom`, `__native`, `__hex`.
- **Swatches:**
  - A swatch is a 1.75rem circle with `background: var(--swatch)` and an inset
    `neutral-200`/`dark:neutral-800` ring, so white swatches stay visible.
  - `[aria-pressed="true"]` shows `__check` and a 2px ring in `neutral-900`/`dark:neutral-100`.
  - `:focus-visible` uses the standard focus outline.
- **Native input:** a 1.75rem square with its UA padding and border reset,
  shown as a chip next to the hex field.
- **Hex field** gets `config.control_class.call(view, :input)` (`UnmagicInput`
  by default), so it matches the gem's other inputs. The section adds only the
  width (`9ch`), a monospace font and tabular numerals.
- **Native colour input** is drawn by the gem as a chip matching the control's
  height and radius.
- **Custom property:** `--swatch` is set inline per swatch. It is a
  per-instance value, not a theme colour.
- **Motion:** the ring transition runs at 100ms and is off under reduced
  motion.

## Behaviour (JavaScript)

`color_picker.js` defines `<unmagic-color-picker>`.

- **Syncing:**
  - Swatch click: set the hex input, set the native input, update
    `aria-pressed`.
  - Native `input`: lowercase the value into the hex field and press any
    matching swatch.
  - Hex `input`: when it matches `#rrggbb`, sync the native input and swatches.
    While the value is partial, leave everything alone.
  - Every change dispatches `input` and `change` on the hex input.
- **Form `reset`:** re-sync from the hex input's reset value, after the reset
  task.
- **Events:** `unmagic-color-picker:change`, with `detail: { value }`.
- **Turbo:**
  - `turbo:before-cache`: nothing to close. Re-sync `aria-pressed` and the
    native input from the hex input's `defaultValue`, so a snapshot shows the
    server's colour.
  - `turbo:morph`: the morph resets markup; the state is all attributes Ruby
    renders, so nothing needs re-applying.
  - Snapshot clones: nothing is generated, so there is nothing to rebuild.
  - Streamed in: listeners are on the element itself (constructor), so it
    works on arrival.
- **Dependencies:** none.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.color_picker.swatches` | "Swatches" |
| `unmagic.components.color_picker.custom` | "Custom colour" |

## Specs

`spec/unmagic/components/color_picker_spec.rb`:

- **Swatches:**
  - a button per swatch with `data-value`, `--swatch`, `aria-label` from the
    name, and `aria-pressed` true only for the current value (case-insensitive)
  - the check icon's colour class chosen by luminance (white on dark, `neutral-900` on
    light)
- **Custom inputs:**
  - the hex input has the name, `pattern` and the current value
  - the native input has no name
  - `custom: false` omits both, and the hex value then rides on a hidden input
- **`as: :color_picker` inside `field`:** `required` and `aria-invalid` land on
  the hex input.
- **Control class seam:** the hex input carries the control class
  (`UnmagicInput` by default, replaced or dropped through `control_class`).
- **`ArgumentError`:** a malformed swatch hex, or swatches given as an array
  without names.

## Preview

On the Forms page (or `primitives`):
- a label colour picker with eight swatches including white and near-black
- a swatches-only picker
- a custom-only picker (`swatches: {}`)
- all shown with the submitted value

Check by hand:
- VoiceOver reads the swatch names and pressed state.
- Paste `#3B82F6` and the Blue swatch becomes pressed.
- The native picker updates the hex field.
- Reset restores the colour; Turbo back shows the saved colour.
- Dark theme: the white swatch ring is visible, and the check is readable on
  every swatch.

## Open questions

1. **Alpha:** Chromium supports `<input type="color" alpha>` but the others
   don't consistently. Leave opacity out?
2. **Tailwind palette names as a built-in preset** (`swatches: :tailwind`):
   useful, or palette opinion the gem shouldn't hold?
3. **Eyedropper:** add an EyeDropper API button where supported, or leave it
   to the native chooser, which already has one on most platforms?

## Comparison with the native input

| | Native `<input type=color>` | Custom saturation and hue canvas (replace) | This note (enhance) |
|---|---|---|---|
| **What users gain** | The operating system chooser: an eyedropper, saved colours, colour spaces | An in-page picker that looks the same on every platform; alpha possible | Named brand swatches in one click, hex paste and typing, and the native chooser still available |
| **Accessibility** | The operating system chooser is accessible, but the input itself only announces a hex value | High cost: a 2-D canvas has no good ARIA pattern, and slider fallbacks triple the keyboard surface; colours must still be named | Low cost: swatches are named toggle buttons, and the hex field is a text input |
| **Mobile** | The operating system sheet, which is good | Dragging on a small canvas is imprecise, and it needs extra touch handling | Swatches are large touch targets; the native sheet is kept |
| **Locale** | None needed | Colour names and labels are ours to translate | Swatch names are the host's (translatable); two I18n keys |
| **JS and data** | None | Roughly 8–12 KB, plus canvas drawing and colour maths | About 1–2 KB; no data |

**Recommendation: enhance.** A custom canvas buys a consistent look and alpha,
at a large accessibility and mobile cost. Named swatches plus hex entry are
what application UIs (labels, avatars, accents) actually use, and the native
chooser remains for anything else.
