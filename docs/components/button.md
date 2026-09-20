# `button`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `button_classes` (the class string it wears), `spinner`
> (its loading state), `button_group`, `FormBuilder#submit`

## Purpose

A button, a link that looks like one, or a `button_to` form, from one call, so a
view says what it wants done and not which element does it. `button_classes`
stays for the places a class string is all that fits: `form.submit`, a `<summary>`.

## API

```erb
<%= button "Save", :primary, type: "submit" %>
<%= button "New label", href: new_label_path, icon: :plus %>
<%= button "Delete", :danger, href: label_path(@label), method: :delete, form: { data: { turbo_confirm: "Sure?" } } %>
<%= button "Close", :icon, icon: :x %>
<%= button "Saving", :primary, loading: true %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label` (positional) or block | String | — | The `:icon` variant keeps it as `aria-label` and `title` |
| `variant` (positional) | `:default`, `:primary`, `:ghost`, `:danger`, `:icon` | `:default` | `button_classes`' variants; validated |
| `size:` | `:small`, `:large`, `nil` | `nil` | Validated |
| `icon:` | Symbol from the gem's Lucide set, or markup | `nil` | Leads the label |
| `href:` | URL | `nil` | Renders `link_to`; with `method:` other than GET, `button_to` |
| `method:` | `:delete`, `:patch`, … | `nil` | `button_to`'s `form:`, `params:` pass through |
| `loading:` | Boolean | `false` | `aria-busy`, disabled, spinner in the icon's place |
| `disabled:` | Boolean | `false` | `disabled` on a button or form; `aria-disabled` + `tabindex=-1` on a link |
| `block:` | Boolean | `false` | Fills the width |
| `type:` | `"button"`, `"submit"` | `"button"` | A plain button never submits by accident |

Other options go on the element.

## Markup

```html
<button type="button" class="UnmagicButton UnmagicButton--primary">
  <svg class="UnmagicIcon UnmagicButton__icon" aria-hidden="true">…</svg><span class="UnmagicButton__label">New label</span>
</button>
<a href="/docs" class="UnmagicButton">…</a>
<form class="UnmagicButton__form" method="post" action="/labels/1"><input type="hidden" name="_method" value="delete"><button type="submit" class="UnmagicButton UnmagicButton--danger">…</button></form>
```

## Accessibility

- A native `<button>`, `<a>` or `<form>`; nothing is a div with a role.
- Icon-only buttons are named by `aria-label` and given a `title`.
- Loading sets `aria-busy="true"` and `disabled`; the spinner is decorative.
- A disabled link is `aria-disabled` and out of the tab order, since `<a>` has
  no `disabled`.

## Styling

Section **Buttons**: `UnmagicButton__icon`, `__label`, `__form`, `--block`, on
top of the existing variants and sizes.

## Small screens

Every `UnmagicButton` is at least 44px tall under `(pointer: coarse)`, and an
icon button at least 44px wide. `block: true` for the one action a phone screen
ends in.

## Behaviour (JavaScript)

None.

## Specs

`spec/unmagic/components/buttons_spec.rb`.
