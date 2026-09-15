# `one_time_code_field`

> Status: draft
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Two Factor" (gap source). A FormBuilder
> control like `autogrow_text_area`.

## Purpose

The input for a short code someone has been sent or generated: a TOTP code, an
email sign-in code, a phone verification code. It looks like a row of boxes,
one per character, so the expected length is obvious and a mistyped character
is easy to spot.

It is not for passwords (see `password_field.md`) or for long tokens such as
recovery codes. Use a plain field for those.

## API

```erb
<%= form.field :code, "Verification code", as: :one_time_code_field, length: 6,
      hint: "We sent it to ada@example.com." %>

<%= form.one_time_code_field :code, length: 8, charset: :alphanumeric, submit: true %>

<%= one_time_code_field_tag "code", length: 6 %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `length:` | Integer 4–10 | `6` | Validated; raises `ArgumentError` |
| `charset:` | `:numeric`, `:alphanumeric` | `:numeric` | Validated. Sets `inputmode`, `pattern` and what the element accepts |
| `submit:` | Boolean | `false` | Submits the form as soon as the last character is entered |
| any other option | | | Goes on the `<input>` |

- **FormBuilder:** `one_time_code_field(method, options = {})`.
- **Helper:** `one_time_code_field_tag(name, value = nil, **options)`.
- The value is never pre-filled from the object. A one-time code isn't echoed
  back after a failed attempt, so `value: nil` unless passed explicitly.

## Markup

**One real input, not one input per box.** The server renders a single
complete control:

```html
<unmagic-one-time-code class="UnmagicOneTimeCode" length="6" charset="numeric">
  <input type="text" name="session[code]" id="session_code" class="UnmagicOneTimeCode__input UnmagicInput"
         inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}"
         maxlength="6" spellcheck="false" autocapitalize="off" required>
</unmagic-one-time-code>
```

**Classes on the input:**
- `UnmagicOneTimeCode__input` is structural and always present: it positions
  the input over the cells once upgraded.
- The look comes from the Configuration seam,
  `Components.configuration.control_class.call(view, :one_time_code)`, which
  returns `"UnmagicInput"` by default. That is the input's appearance before
  upgrade or without script.
- A host can return its own classes or `nil`, and a caller's `class:` merges
  after.

On upgrade the element adds the boxes, as a visual layer the input sits over:

```html
<div class="UnmagicOneTimeCode__cells" aria-hidden="true">
  <span class="UnmagicOneTimeCode__cell" data-filled>4</span>
  <span class="UnmagicOneTimeCode__cell" data-active></span>
  …
</div>
```

**Why a single input.** A row of separate inputs breaks the things this field
most needs:
- SMS and email autofill, and password-manager TOTP fill, put the code into
  **one** field
- paste needs custom handling in every browser
- a screen reader announces six unlabelled "edit text" fields
- validation, `required`, `pattern` and `field`'s `aria-invalid` and error line
  apply to one control

With one input, typing, Backspace, Delete, arrow keys, selection, paste and
autofill are all native. The element only draws. Without script it's a plain,
fully working code input.

## Accessibility

- One text field, labelled by `field`'s label and described by its hint and
  error. The cells are `aria-hidden`.
- `autocomplete="one-time-code"` and `inputmode` bring up the right keyboard
  and the platform's code suggestion.
- **`submit: true`** only submits after a real edit reaches full length, never
  on connect with a pre-filled value. It uses `form.requestSubmit()`, so
  validation and Turbo still run. The docs warn that auto-submit can surprise
  screen-reader users, and suggest keeping a visible submit button.

| Key | Does |
|---|---|
| Characters | Fill the next cell (native insert); anything not in `charset` is dropped |
| Backspace / Delete | Remove a character (native) |
| ← / → / Home / End | Move the caret; the active cell follows |
| Paste, autofill | Native, then sanitised and trimmed to `length` |

## Styling

- CSS section **One-time code**:
  - `UnmagicOneTimeCode`, `__input`, `__cells`, `__cell`
  - `[data-filled]`, `[data-active]`
All selectors are classes, never bare elements.

- **Before upgrade** (`.UnmagicOneTimeCode:not([data-ready])`):
  - the input looks like any gem input (the shared `UnmagicInput` rule in
    **Forms**, with its `:disabled`, `[aria-invalid=true]` and
    `:focus-visible` states)
  - `.UnmagicOneTimeCode__input` adds `font-variant-numeric: tabular-nums` and
    `letter-spacing: 0.3em`
- **After upgrade** (`.UnmagicOneTimeCode[data-ready]`):
  - the cells are an inline grid of `length` columns, each `2.5rem × 3rem`,
    styled like `UnmagicInput` (`neutral-300`/`dark:neutral-700` border, 0.5rem
    radius, `white`/`dark:neutral-900`), with
    1.25rem tabular text
  - `.UnmagicOneTimeCode[data-ready] .UnmagicOneTimeCode__input` is stretched
    over them with `position: absolute; inset: 0`
    - transparent text and caret
    - no border, background or outline, overriding the control class at higher
      specificity
    - it is still the real input that's clicked, focused and submitted
- **States:** read from the real input with `:has()`, so they follow
  `:disabled`, `[aria-invalid=true]` and `:focus-visible` exactly as a plain
  `UnmagicInput` does:
  - **Focus:** `.UnmagicOneTimeCode:has(.UnmagicOneTimeCode__input:focus-visible) .UnmagicOneTimeCode__cell[data-active]`
    gets the `neutral-400`/`dark:neutral-500` outline and a blinking caret bar (`::after`).
  - **Invalid:** `:has(.UnmagicOneTimeCode__input[aria-invalid="true"])`
    recolours every cell border with `red-600`/`dark:red-400`.
  - **Disabled:** `:has(.UnmagicOneTimeCode__input:disabled)` dims the cells
    and sets `cursor: not-allowed`.
- **Host opts out:** if the seam returns `nil`, the cells still render the
  gem's look, since they exist only when upgraded. Only the pre-upgrade input
  is left to the host.
- **Motion:** the caret blink is switched off under reduced motion (a solid
  bar instead).
- **Colours:** the `UnmagicInput` palette and `dark:` variants only.

## Behaviour (JavaScript)

The element is `<unmagic-one-time-code length charset>`.

- **On connect:**
  - remove any `:scope > .UnmagicOneTimeCode__cells` a snapshot clone brought
    along
  - build `length` cells
  - set `data-ready`
  - sync
- **On `input`:**
  - strip characters outside the charset (and upper-case `alphanumeric`)
  - trim to `length`
  - restore the caret if the value changed
  - sync
  - fire `unmagic-one-time-code:complete` with `{ value }` when it reaches full
    length, and submit if `submit`
- **On `selectionchange`, `focus`, `blur`** (and `keyup` as a fallback): move
  `data-active` to the cell at `selectionStart`, clamped to the last cell.
- **On the form's `reset`:** sync after the reset's task.

Turbo:
- **`turbo:before-cache`:** clear the value and sync. The code is one-time and
  sensitive, so it has no place in a snapshot.
- **`turbo:morph`:** the server renders no value, and a morph after a failed
  attempt leaves the input empty. Sync the cells to whatever the input now
  holds, and keep `data-ready`, which the morph removes because the server
  doesn't render it.
- **Snapshot clones:** stale cells are removed and rebuilt on connect.
- **Streamed content:** connect builds everything; nothing is document-level
  except the form `reset` listener, which is removed in `disconnectedCallback`.
- **Dependencies:** none.

## I18n

None. The label and hint come from `field`.

## Specs

In `spec/unmagic/components/one_time_code_spec.rb`:

- The builder renders one `input` inside `unmagic-one-time-code`, with
  `autocomplete="one-time-code"`, `maxlength` and the `length` attribute.
- `charset: :numeric` gives `inputmode=numeric` and `pattern="[0-9]{6}"`, and
  `:alphanumeric` gives `inputmode=text` and `pattern="[A-Za-z0-9]{8}"`.
- It works through `field … as: :one_time_code_field`, with `aria-invalid` and
  the error.
- A value on the object isn't rendered; an explicit `value:` is.
- `submit: true` renders the `submit` attribute.
- No cells are server-rendered.
- `ArgumentError` for `length: 3`, `length: 11`, a non-integer and an unknown
  `charset:`.
- The `_tag` form has the name and id.
- The control class seam:
  - by default the input has `UnmagicOneTimeCode__input UnmagicInput`
  - a configured `control_class` receives `:one_time_code` and its return value
    replaces `UnmagicInput`
  - `nil` leaves only `UnmagicOneTimeCode__input`
  - a caller's `class:` merges last

## Preview

A "Verify" block on `elements`:
- 6-digit numeric
- 8-character alphanumeric with `submit: true`, posting to a preview endpoint
  that flashes a toast
- one in its error state

Check by hand:
- type, Backspace, arrows, and click on a cell
- paste "123 456" and "12-34-56"
- iOS/macOS code autofill if available
- VoiceOver reads a single field
- JS disabled
- Back after a submit clears it
- dark theme
- reduced motion

## Open questions

- **Separators** for grouped codes ("123-456")? The proposal is a later
  `group: 3` option that inserts a purely visual gap between cells.
- **Masking** (dots instead of characters), for codes that are secret on a
  shared screen? The proposal is not yet: codes are short-lived, and masking
  hurts error spotting.
- **Tolerance:** should the server-side param be normalised (spaces and dashes
  stripped) by the gem, or left to the app? The proposal is left to the app;
  the element already sanitises what it can.
