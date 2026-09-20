# `button_group`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `button`, `toggle_group` (a group that holds a choice)

## Purpose

Buttons joined edge to edge into one control: a set of views, a pair of steps, a
split action. It groups; it does not hold a choice. For one-of-many, use
`toggle_group` (or `tabs`).

## API

```erb
<%= button_group label: "View" do |group| %>
  <% group.button "List", icon: :list_checks, "aria-pressed": "true" %>
  <% group.button "Board", icon: :folder %>
  <% group.item { menu … } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | String | `nil` | The group's `aria-label` |
| `orientation:` | `:horizontal`, `:vertical` | `:horizontal` | Validated |

`group.button` takes the `button` helper's arguments; `group.item` anything
else. Other options go on the group. An empty group renders nothing.

## Markup

```html
<div role="group" aria-label="View" class="UnmagicButtonGroup">
  <button class="UnmagicButton">…</button><a class="UnmagicButton">…</a>
</div>
```

## Accessibility

`role="group"` with a label; each member keeps its own semantics. A pressed
member is the caller's `aria-pressed`, which the CSS raises above its neighbours.

## Styling

Section **Button groups**: members lose their shared corners and overlap borders
by a pixel; hover, focus and `aria-pressed` lift a member so its whole edge
shows. `--vertical` stacks.

## Small screens

The run wraps rather than overflowing. Members keep the 44px target.

## Behaviour (JavaScript)

None.

## Specs

`spec/unmagic/components/buttons_spec.rb`.
