# `toggle` and `toggle_group`

> Status: built
> Tier: 2 (a two-line script for the nameless button; none otherwise)
> Replaces or relates to: `tabs` (links between pages; this is a value in a form),
> `button_group` (grouping; this holds a choice), `dark_mode_switcher` (a toggle group of three)

## Purpose

A button that is on or off (bold, wrap lines, show archived), and a run of
them joined into a segmented control that holds one choice, or several.

## API

```erb
<%= toggle "Bold", icon: :pencil, pressed: true, icon_only: true %>
<%= toggle "Show archived", name: "archived", pressed: params[:archived] %>

<%= toggle_group name: "range", value: "7d", label: "Range" do |group| %>
  <% group.option "24 hours", "24h" %>
  <% group.option "7 days", "7d", icon: :clock %>
<% end %>
```

`toggle(label, pressed:, icon:, icon_only:, name:, value:, size:, disabled:)`;
`toggle_group(name:, value:, multiple:, label:, size:) { |g| g.option label, value, icon:, disabled: }`.

## Markup

With a `name:` (and every group option) the toggle is a `<label class="UnmagicToggle UnmagicToggle--input">`
around a visually hidden native `<input type="checkbox|radio" class="UnmagicToggle__input">`
and a `<span class="UnmagicToggle__face">`. Without a name it is
`<button type="button" class="UnmagicToggle" aria-pressed>`. A group is
`<div role="radiogroup" | role="group" aria-label>` of labels.

## Accessibility

Native inputs carry the state and the keyboard: Tab enters the group at the
checked radio and the arrow keys move it; Space flips a checkbox. The face is
the target, the input sits over it at zero opacity. The nameless button is
the APG toggle button with `aria-pressed`. Focus rings draw on the face via
`:has(:focus-visible)`.

## Styling

Section **Toggles**: `UnmagicToggle`, `__input`, `__face`, `__icon`, `__label`,
`--input`, `--icon`, `--small`, `--large`; `UnmagicToggleGroup` with joined
edges. State from `aria-pressed` or `:has(:checked)`.

## Small screens

44px tall on a coarse pointer. A group is one row that scrolls sideways rather
than wrapping, so joined edges stay joined.

## Behaviour (JavaScript)

`import "unmagic/components/toggle"`: one delegated click handler flips
`aria-pressed` on a nameless toggle and fires `unmagic-toggle:change`.
