# `input_group`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `FormBuilder#field` (wraps the control it holds), `button`

## Purpose

A control with something joined to either end of it: a scheme before a
subdomain, a unit after a number, a search icon, a submit button.

## API

```erb
<%= input_group prefix: "https://", suffix: ".example.com" do %>
  <%= form.text_field :subdomain %>
<% end %>
<%= input_group suffix: button("Search", type: "submit") do %>
  <%= search_field_tag :q, params[:q], class: control_classes(:input) %>
<% end %>
```

Text becomes a tinted addon; markup is set in as it is. The block is the control.

## Markup

`div.UnmagicInputGroup` → `span.UnmagicInputGroup__addon[--text]`, the control,
`span.__addon`. The control gives up its corners and shadow; the ends of the
group keep theirs.

## Accessibility

An addon is plain text or a real control; the input keeps its own label
(from `field`, or `aria-label`). A text addon that carries meaning ("per
month") should be in the label or hint too, since it isn't associated.

## Small screens

Full width; the control shrinks and the addons don't.

## Specs

`spec/unmagic/components/form_controls_spec.rb`.
