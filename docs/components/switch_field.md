# `FormBuilder#switch_field` and `#switch`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Switch" (gap source);
> `FormBuilder#check_box_field` (which it mirrors); `config.control_class`

## Purpose

An on/off setting that reads as a setting rather than as agreement:
- "Email me about new replies"
- "Require two-factor for all members"

Underneath it is still a checkbox, so it submits exactly like
`check_box_field` (a hidden "0", then "1"). Choose it over a checkbox for a
preference that takes effect as a state. Keep checkboxes for "I agree" and for
choosing several items from a list.

## API

```erb
<%= form.switch_field :notify_replies, "Email me about new replies" %>
<%= form.switch_field :require_2fa, "Require two-factor", hint: "Members without it are signed out." %>

<%# The bare control, for a table cell or your own layout %>
<%= form.switch :enabled, "aria-label": "Enabled" %>

<%# Outside a form builder %>
<%= switch_tag "user[notify]", checked: @user.notify?, label: "Notify me" %>
```

- **`switch_field(method, label_text, hint: nil, **options)`** has the same
  signature as `check_box_field`. The options go on the `<input>`, including
  `disabled:` and `data:`.
- **`switch(method, options = {}, checked_value = "1", unchecked_value = "0")`**
  is `check_box`'s signature, with `role="switch"` and the switch class added.
  It works as `field`'s control via `as: :switch`.
- **`switch_tag(name, value = "1", checked: false, label: nil, **options)`**
  is `check_box_tag` with the same class and role. With `label:` it renders the
  labelled layout.
- **The class** comes from `config.control_class.call(view, :switch)`, which
  returns `"UnmagicSwitch"` by default. A host can return its own classes, or
  `nil` to leave the input unstyled. A caller's `class:` is merged after it.
- **Errors:** an invalid attribute gets `aria-invalid="true"` on the input.
  `switch_field` doesn't render error text, mirroring `check_box_field`; wrap it
  in `field` for an error line.

## Markup

```html
<label class="UnmagicCheckField UnmagicCheckField--switch">
  <input name="user[notify_replies]" type="hidden" value="0" autocomplete="off">
  <input class="UnmagicSwitch" type="checkbox" role="switch" value="1"
         name="user[notify_replies]" id="user_notify_replies">
  <span class="UnmagicCheckField__text">
    <span class="UnmagicCheckField__label">Email me about new replies</span>
    <span class="UnmagicHint">Members without it are signed out.</span>
  </span>
</label>
```

- **One real input, no extra elements.** The switch is the checkbox itself, with
  `appearance: none` and drawn with CSS. Clicks, focus, form reset, autofill and
  `:checked` stay native, and there is nothing decorative to keep in sync.
- **The thumb** is a `radial-gradient` background on the input rather than a
  `::before`, because pseudo-elements don't render on inputs in Firefox.
  Checking moves `background-position`.
- **The WebKit `switch` attribute** isn't used: support is too narrow, and it
  would draw differently between browsers.
- **Layout** reuses `UnmagicCheckField`, with a `--switch` modifier for
  alignment only.

## Accessibility

- **Pattern:** follows the APG
  [Switch pattern](https://www.w3.org/WAI/ARIA/apg/patterns/switch/). A
  checkbox with `role="switch"` announces "on" or "off", and Space toggles it
  natively.
- **Label:** the wrapping `<label>` names it. The bare `switch` needs the
  caller's `aria-label` or a `label for`.
- **Focus:** `:focus-visible` draws the standard ring on the input itself.
- **State:** never shown by colour alone; the thumb position changes too.
  Disabled dims the switch and sets `cursor: not-allowed`.
- **Forced colours:** under `@media (forced-colors: active)` the gradients
  vanish, so the track gets a `CanvasText` border and the checked state a
  `Highlight` background.

## Styling

CSS: in the `Forms` section, next to `UnmagicCheck` and `UnmagicRadio`.

- **Classes:** `UnmagicSwitch` and `UnmagicCheckField--switch`.
- **Track:**
  - `appearance: none`, `2.25rem × 1.25rem`, `margin: 0`, radius 9999px,
    `flex-shrink: 0`, `cursor: pointer`.
  - Off: background `--unmagic-text-3`, not `--unmagic-border-strong`.
    - In the preview's dark theme, `--unmagic-raised` (#34333f) on
      `--unmagic-border-strong` (#38364a) is nearly invisible.
    - `--unmagic-text-3` gives the thumb contrast in both themes: white on
      neutral-500 in light, and #34333f on #817e8d in dark.
  - `:checked`: `--unmagic-accent`.
- **Thumb:** a 1rem circle drawn with
  `radial-gradient(circle, var(--unmagic-raised, var(--unmagic-surface, var(--color-white, #fff))) 0.5rem, transparent calc(0.5rem + 0.5px))`.
  `background-size` is the height; `background-position` runs from left to
  right when `:checked`.
- **States:**
  - `:focus-visible`: 2px `--unmagic-focus` outline with a 2px offset.
  - `:disabled`: opacity 0.5, `cursor: not-allowed`.
  - `[aria-invalid="true"]`: a 2px box-shadow ring in `--unmagic-bad`.
- **Motion:** a 150ms transition on `background-position` and
  `background-color`, off under reduced motion.
- **Alignment:** `UnmagicCheckField--switch` sets `align-items: center` when
  there is no hint and keeps `flex-start` with one, matching checkboxes.
- **No new tokens (decided).**
  - The thumb reuses `--unmagic-raised`, the "lifted out of a track" surface
    the selected tab already uses. It falls back to `--unmagic-surface`, then
    white.
  - The off-track colour above is chosen so that surface shows against it.

## Behaviour (JavaScript)

_None. CSS and markup only._

The native checkbox handles toggling, reset and restoring state after a cache
visit.

## I18n

None.

## Specs

In `spec/unmagic/components/form_builder_spec.rb`:

- **`switch_field`:**
  - renders `label.UnmagicCheckField.UnmagicCheckField--switch`
  - containing `input[type=hidden][value="0"]` and
    `input.UnmagicSwitch[type=checkbox][role=switch][value="1"]`
  - then the label text and hint
- **Checked state:** `checked` when the model attribute is true (`Signup#terms`).
- **Validation errors:** `aria-invalid="true"` on the checkbox.
- **Passthrough:**
  - `disabled: true` and `data:` reach the checkbox
  - `class: "x"` gives `class="UnmagicSwitch x"`
  - a custom `checked_value` / `unchecked_value` is respected
- **Bare control:** `form.switch :terms` renders `input.UnmagicSwitch[role=switch]`
  with no label wrapper, and works as `field ... as: :switch`.
- **Seam:**
  - `config.control_class = ->(_view, kind) { "toggle toggle-#{kind}" }` →
    `class="toggle toggle-switch"`
  - returning `nil` → no class, with `role="switch"` still present
- **`switch_tag`:** name, `checked`, class and role, and the label layout when
  given `label:`.

## Preview

The form on the `dialogs` page ("edit profile"), plus a settings `card` on
`primitives` with three switches:
- one with a hint
- one disabled
- one invalid

**Check by hand:**
- Click and Space toggle it; the label click toggles it.
- The focus ring shows.
- `form.reset()` restores it.
- Thumb contrast in the dark theme, on and off: `--unmagic-raised` against
  `--unmagic-text-3` and against `--unmagic-accent`.
- No transition under reduced motion.
- Forced-colours mode (Windows High Contrast emulation in DevTools) still shows
  the state.
- VoiceOver reads "switch, off".

## Open questions

- **Instant-save switches.** Switches that save on toggle, e.g. with
  `data: { turbo_submit_on_change: true }`, would need a small element, so they
  are proposed for Tier 2 if wanted.
