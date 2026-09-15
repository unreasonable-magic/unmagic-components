# `helper_name`

> Status: draft | reviewed | built
> Tier: 1 (no JS) | 2 (small element) | 3 (large) | marketing
> Replaces or relates to: existing components it builds on or sits beside

## Purpose

What it is for, in two or three sentences, and the situation in an application
where a view reaches for it. Say what it is **not** for, and which existing
component to use instead.

## API

```erb
<%# The common case, with no options %>
<%= helper_name "…" %>

<%# The fuller case: every option, and the builder's parts %>
<%= helper_name option: :value do |thing| %>
  <% thing.part "…" %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `option:` | `:a`, `:b` | `:a` | Validated; raises `ArgumentError` |

- Builder parts and their arguments.
- Where other options go.
- What blank or empty input renders.
- The `FormBuilder` method and `_tag` form, if it is a form control.

## Markup

The HTML Ruby renders, with classes and ARIA, before any script runs:

```html
<div class="UnmagicThing UnmagicThing--a">
  …
</div>
```

Which native element it builds on, and why.

## Accessibility

- The WAI-ARIA pattern it follows (link it).
- Roles and states: which the server renders, and which script keeps true.
- Keyboard: every key and what it does.
- Focus: where it goes on open and on close.
- Names and announcements: labels, live regions, `aria-hidden` icons.

## Styling

- CSS section name and its BEM elements and modifiers.
- Which attributes drive state (`[aria-expanded]`, `[data-open]`).
- Tokens it uses, and any **new** token with its reason and fallback.
- Motion, and what `prefers-reduced-motion` switches off.

## Behaviour (JavaScript)

_None: CSS and markup only._ Or:

- The element's name (`<unmagic-thing>`) and the attributes it reads.
- What it adds on top of the native markup.
- Events it fires (`unmagic-thing:change`).
- Turbo: what it does on `turbo:before-cache`, on `turbo:morph`, when cloned
  from a snapshot, and when streamed in.
- Dependencies: sibling modules, and whether it needs Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.thing.label` | "…" |

## Specs

What `spec/unmagic/components/<group>_spec.rb` asserts:

- Structure and classes for each variant.
- ARIA wiring (ids that link parts together).
- Passthrough `class:` and attributes.
- `ArgumentError` for each validated option.
- Edge cases (blank content, a single item).

## Preview

- Page (`primitives`, `elements`, `dialogs` or a new one) and what the section
  shows.
- What to check by hand: keyboard walkthrough, dark theme, reduced motion,
  Turbo navigation back and forth.

## Open questions

- Anything that needs a decision before it's built.
