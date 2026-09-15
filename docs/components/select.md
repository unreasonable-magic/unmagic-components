# `FormBuilder#select` (`UnmagicSelect`)

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Select" (gap source). Styled through the `config.control_class` seam alongside `UnmagicInput`, `UnmagicCheck` and `UnmagicRadio`. Sits beside `combobox` (combobox.md), which owns search, multi-select and custom option markup.

## Purpose

A single-choice dropdown from a short, fixed list (a role, a country, a
status) that looks at home next to the gem's other controls.

## Decision: a styled native `<select>`, not a custom listbox

The gem styles form controls. Styles hang off classes, and the builder adds the
class through `config.control_class`.

**Recommendation:** a native `<select>` with the `UnmagicSelect` class, fully
styled with CSS `appearance: base-select` where the browser supports it. It is
**not** a scripted listbox.

**Why:**

1. **Native elements come first** (principle 2). A native select brings
   keyboard type-ahead, mobile pickers, form reset, `required` validation,
   autofill, and screen-reader support that a custom listbox has to rebuild,
   and usually rebuilds worse.
2. **The combobox already exists as the scripted option.** Anything that needs
   search, multiple values, remote options or rich option markup is a combobox.
   Two scripted dropdowns with overlapping keyboard models would be worse than
   one.
3. **Customisable select is shipping.** `appearance: base-select` gives a
   stylable button and a top-layer picker in Chromium. Every other browser
   already gets the closed select that shipped with the form-control styling:
   the gem's box, and an arrow drawn in the text colour. The progressive path
   only adds the open picker's look.
4. **It needs no wrapper and no script.** The class sits on the `<select>`
   itself, so `form.select`, `select_tag` and a host's hand-written select all
   style the same way.

**Placement:** core CSS.

## API

```erb
<%= form.field :role, "Role" do %>
  <%= form.select :role, Role.all.map { [ _1.name, _1.id ] }, include_blank: "Choose a role" %>
<% end %>

<%= form.field :status, "Status", as: :select, choices: %w[Open Closed] %>

<%# Outside a builder %>
<%= select_tag "status", options_for_select(%w[Open Closed]), class: control_classes(:select) %>
```

- **`FormBuilder#select`** (and `collection_select`, `grouped_collection_select`,
  `time_zone_select`) merges `config.control_class.call(view, :select)` into
  `html_options[:class]`.
  - The default seam returns `"UnmagicSelect"`. A host can return its own
    classes, or `nil` to opt out.
  - A caller's `class:` is kept after the seam's.
- **`field ... as: :select, choices:`** is supported: `field` passes `choices`
  positionally.
- **`control_classes(kind, size: nil)`** is the view-helper counterpart to
  `button_classes`, for controls outside a builder.
  - `size: :small` adds `UnmagicSelect--small`.
  - `ArgumentError` for an unknown kind or size.
- **`aria-invalid="true"`** is set when the attribute has errors, as `field`
  already does for its built controls.
- **`base_select: true`** in `html_options` emits
  `<button><selectedcontent></selectedcontent></button>` as the first child, so
  an option's icon can show in the closed state. Other browsers ignore it.

## Markup

```html
<select class="UnmagicSelect" name="user[role]" id="user_role" aria-invalid="true">
  <option value="">Choose a role</option>
  <option value="1">Engineer</option>
</select>
```

## Accessibility

It is entirely native: role, keyboard, type-ahead and announcements. Keep:

- a real `<label for>`, which comes from `field`
- a visible `:focus-visible` ring
- invalid state shown by border **and** by the error text `field` renders, not
  colour alone
- that it never replaces the native picker on mobile

## Styling

- **Section:** `Select`, part of the new form-controls group with `Input`,
  `Check` and `Radio`. It shares their box rules.
- **Modifiers:** `--small` and `--large`, matching `button_classes` sizes.
- **Base (all browsers):** already built in `engine.css`; this note only adds
  the customisable-select layer below.
  - padding and 0.875rem type matching `UnmagicInput`
  - `white`/`dark:neutral-900` background, `neutral-300`/`dark:neutral-700`
    border, 0.375rem radius, `neutral-900`/`dark:neutral-100` text
  - `:focus-visible` in `neutral-400`/`dark:neutral-500`
  - `[aria-invalid="true"]` uses `red-600`/`dark:red-400`
  - `:disabled` uses a `neutral-50`/`dark:neutral-800/50` background and
    `neutral-500` text
  - `appearance: none` with an arrow drawn from two `currentColor` gradient
    triangles, so it follows the text colour in both themes (a select can't
    hold a pseudo-element)
  - `[multiple]` and a `size` above 1 drop the arrow
  - under `forced-colors: active`, the native arrow comes back
    (`appearance: auto`)
- **Customisable select:** under `@supports (appearance: base-select)`:
  - `.UnmagicSelect, .UnmagicSelect::picker(select) { appearance: base-select }`
  - `::picker-icon` is coloured `neutral-500`, and rotates while `:open`.
  - The picker gets the `UnmagicMenu__panel` look: `white`/`dark:neutral-900`,
    `neutral-200`/`dark:neutral-800`, 0.5rem
    radius, and the menu shadow.
  - `option` gets the `UnmagicMenu__item` padding and radius; `option:hover`
    and `:checked` use `neutral-100`/`dark:neutral-800`; `option::checkmark` uses
    `neutral-900`/`dark:white`.
- **Motion:** a 100ms picker fade and icon rotation, removed under reduced
  motion.
- **Colour:** palette with `dark:` variants only.

## Behaviour (JavaScript)

_None._

## I18n

None. The caller supplies the `include_blank` and `prompt` text.

## Specs

- `form.select` renders `select.UnmagicSelect`, and choices, `selected` and
  `include_blank` still work.
- A caller's `class:` is appended after the seam's.
- `config.control_class = ->(_, kind) { "my-#{kind}" }` replaces the class, and
  returning `nil` renders no class.
- `collection_select` gets the class too.
- `field :status, as: :select, choices:` renders the label `for` matching the
  id.
- `aria-invalid` is set when there are errors.
- `base_select: true` emits `button > selectedcontent`.
- `control_classes(:select, size: :small)` returns
  `"UnmagicSelect UnmagicSelect--small"`, and raises `ArgumentError` for an
  unknown kind or size.

## Preview

- **Page:** the `forms` page, which already shows builder and `select_tag`
  selects in every size.
- **Hand-check:**
  - Chromium (base-select picker), and Safari and Firefox (the gem's box and
    drawn arrow).
  - Keyboard type-ahead.
  - Mobile picker.
  - Invalid state.
  - Dark mode picker surface.

## Open questions

- Should `base_select: true` become the default output once Firefox and Safari
  ship customisable select?
- Should `grouped_collection_select`'s `optgroup` labels get their own styling
  in the base-select picker?
