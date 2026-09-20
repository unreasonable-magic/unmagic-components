# `password_field reveal: true`

> Status: built
> Tier: 2 (small element)
> Replaces or relates to: Rails Blocks "Password" (gap source). Overrides the
> builder's `password_field`, as `FormBuilder` already overrides `label` and
> `submit`.

## Purpose

A password input with a button that shows what's been typed, so people can
check a long password before submitting. It is for sign-in, sign-up and
password change forms.

It is **not** a strength meter (see Open questions). It is also not for secrets
the app shows back to the user, such as API keys: use `copy_button` with a
masked value for those.

## API

```erb
<%= form.field :password, "Password", as: :password_field, reveal: true,
      autocomplete: "current-password", required: true %>

<%= form.password_field :password, reveal: true, autocomplete: "new-password" %>

<%= password_field_tag "password", nil, reveal: true, autocomplete: "current-password" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `reveal:` | `true`, `false` | `false` | Adds the show/hide toggle and the `<unmagic-password>` wrapper |
| `autocomplete:` | string | none | Passed through. The docs push `current-password` / `new-password` |
| any other option | | | Goes on the `<input>`, as with Rails' `password_field` |

- **FormBuilder:** `password_field(method, options = {})` overrides Rails'
  method.
  - Without `reveal:` (or with `reveal: false`) it is exactly Rails' input,
    plus the `:password` control class from the seam. No wrapper, no element.
  - With `reveal: true` it removes the key, calls `super`, and wraps the result.
  - It works as a `field`'s control (`as: :password_field`), so `required` and
    `aria-invalid` from `field` reach the input.
- **Helper:** `password_field_tag(name, value = nil, **options)` is overridden
  in `ActionViewHelpers` the same way. Without `reveal:` it only adds the
  control class.
- **Why override rather than add a new method.** `FormBuilder` already
  overrides `label` (to add `UnmagicLabel`) and `submit` (to add the submitting
  text), so overriding has precedent. `reveal:` is opt-in, so every existing
  call renders the same markup as before, apart from the control class that
  every gem control now gets.

## Markup

With `reveal: true`:

```html
<unmagic-password class="UnmagicPassword">
  <input type="password" name="user[password]" id="user_password"
         class="UnmagicPassword__input UnmagicInput"
         autocomplete="current-password" required>
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicPassword__toggle"
          aria-controls="user_password" aria-pressed="false" aria-label="Show password"
          title="Show password" hidden>
    <svg class="UnmagicIcon UnmagicPassword__show" aria-hidden="true">…eye…</svg>
    <svg class="UnmagicIcon UnmagicPassword__hide" aria-hidden="true">…eye_off…</svg>
  </button>
</unmagic-password>
```

Without `reveal:`:

```html
<input type="password" name="user[password]" id="user_password" class="UnmagicInput">
```

- **Classes on the input:**
  - `UnmagicPassword__input` is structural and appears only with `reveal:`: it
    makes room for the toggle.
  - The look comes from the seam,
    `Components.configuration.control_class.call(view, :password)`. It returns
    `"UnmagicInput"` by default, the same look as every gem input.
  - A host can return its own classes, or `nil` to opt out. A caller's `class:`
    is merged after.
- **`UnmagicPassword` on the wrapper** is structural (it positions the toggle),
  so it isn't subject to the seam.
- **The button renders `hidden`** and the element reveals it on upgrade.
  Without script there is simply a working password field, not a dead button.
- **`aria-controls` uses the input's id:** `options[:id]` or `field_id(method)`
  in the builder, and `sanitize_to_id(name)` in the tag helper.
- **Two new Lucide glyphs** go into `Icons::PATHS`: `:eye` and `:eye_off`.

## Accessibility

- **A toggle button with a fixed name and a pressed state.** It is always
  called "Show password", with `aria-pressed="true"` while revealed, as the
  [APG button](https://www.w3.org/WAI/ARIA/apg/patterns/button/) toggle
  guidance recommends. The name doesn't flip between show and hide.
- **The input keeps what `field` gives it:** its label, and its
  `aria-describedby` hint and error.
- **Tab order:** the button comes after the input, so Tab from the password
  reaches it. Some password managers inject icons at the input's inline end,
  and the padding leaves room for one.

| Key | Where | Does |
|---|---|---|
| Enter / Space | toggle | Shows or hides; focus stays on the button |

- **Caret:** toggling keeps the input's selection, restored from
  `selectionStart`/`selectionEnd`, so a click mid-typing doesn't lose the
  place.

## Styling

- CSS section **Password**: `UnmagicPassword`, `__toggle`, `__show` and
  `__hide`.
- `.UnmagicPassword` is `display: block; position: relative`.
- The toggle is absolutely positioned at `inset-inline-end: 0.25rem`, centred
  vertically.
- **`.UnmagicPassword__input`** gets `padding-inline-end: 2.5rem`, which is
  room for the toggle.
  - Its look (border, radius, surface, and the `:disabled`,
    `[aria-invalid=true]` and `:focus-visible` states) is the shared
    `UnmagicInput` rule in the **Forms** section, not repeated here.
  - All selectors are classes. A descendant rather than child selector, because
    Rails' `field_with_errors` div can sit in between.
- **`.UnmagicPassword__toggle` is hidden while the input is `:disabled`**, via
  `.UnmagicPassword:has(.UnmagicPassword__input:disabled)`.
- **Icon swap:** `.UnmagicPassword[data-revealed] .UnmagicPassword__show { display: none }`,
  and the inverse for `__hide`.
- **Colours:** `neutral-500` for the icon, and the focus ring.
- **Motion:** none.

## Small screens

The reveal button is an icon button, 44px on a coarse pointer, and the input keeps room for it.

## Behaviour (JavaScript)

The element is `<unmagic-password>`, and it is rendered only with `reveal: true`.

- **On connect:** unhide the button.
- **A click on the toggle:**
  - switches the input between `password` and `text`
  - sets `aria-pressed` and `data-revealed`
  - keeps the selection
  - fires `unmagic-password:toggle` with `{ revealed }`
- **The input always goes back to `type="password"`:**
  - on the form's `submit`, so a browser doesn't offer to save a plain text
    field
  - on `pagehide`
  - on the form's `reset`

**Turbo:**
- **`turbo:before-cache`:** masks the password again. This matters for
  security: otherwise a revealed password would be kept in the cached snapshot
  and shown on Back. Turbo doesn't cache form values by default, but the input
  would still be `type="text"`. See the principles, "Surviving Turbo".
- **`turbo:morph`:** the server renders `type="password"`, so morph masks it.
  Sync `aria-pressed` and `data-revealed` to the input's actual type.
- **Snapshot clones:** a clone may carry an unhidden button, or `type="text"`.
  Connect resets both to the server state, then unhides the button.
- **Streamed content:** listeners are on the element, so there's nothing to do.
- **Dependencies:** none.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.password.show` | "Show password" |

## Specs

In `spec/unmagic/components/password_spec.rb`:

- **Without `reveal:`:**
  - `form.password_field :password` renders a bare `input[type=password]` with
    `UnmagicInput`, and no `unmagic-password`
  - apart from that class, its attributes match Rails' own
  - the same holds for `password_field_tag`
- **With `reveal: true`:**
  - the input is wrapped in `unmagic-password.UnmagicPassword`
  - the toggle is `hidden`, with `aria-controls` equal to the input id and
    `aria-pressed="false"`
  - no `reveal` attribute leaks onto the input
- **Through `field`:** `field :password, as: :password_field, reveal: true`
  keeps `required`, `aria-invalid` and the error line.
- **Ids:** a custom `id:` flows to `aria-controls`.
- **The `_tag` form:** name, value omitted (Rails never echoes a password), and
  the sanitised id.
- **Icons:** both eye icons render `aria-hidden`.
- **Options:** extra options (`autocomplete`, `class`) land on the input, not
  the wrapper. A caller's `class:` merges after
  `UnmagicPassword__input UnmagicInput`.
- **The seam:**
  - by default the input has `UnmagicInput`
  - `config.control_class = ->(_view, kind) { kind == :password ? "input" : nil }`
    gives `UnmagicPassword__input input` with `reveal:`, and `input` without
  - returning `nil` leaves only `UnmagicPassword__input`, or no class without
    `reveal:`

## Preview

On the dialogs page's profile form, or in a new sign-in block on `elements`,
show:
- a `reveal: true` password field with a hint
- the same field with an error
- a plain `password_field` next to it, to show the unchanged default

Check by hand:
- revealing and hiding keeps the caret
- after submit then Back, the field is masked
- the browser's password manager still recognises the field
- keyboard-only use
- dark theme
- with JS disabled, a plain working password field and no button

## Open questions

- **A strength meter.** It's out of scope here. If wanted, it belongs as a
  separate `hint:`-like slot fed by the app's own rules, not a gem heuristic.
