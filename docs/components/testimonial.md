# `testimonial`

> Status: draft
> Tier: marketing
> Replaces or relates to: Rails Blocks "Testimonial" (gap source). Builds on `avatar` (see avatar.md) and sits beside `card`.

## Purpose

A quote from a person, with attribution: name, role and avatar, plus an
optional rating or logo. For landing, pricing and sign-up pages.

Not for in-app comments or activity feeds; those are the host's own markup.

**Placement (decided):** a core `Testimonial` section in `components.css`,
shipped like every other component. Marketing-style components live in the core
stylesheet.

## API

```erb
<%= testimonial "It replaced three internal tools in a week.",
      name: "Ada Lovelace", role: "CTO, Analytical Engines", avatar: "ada.jpg" %>

<%= testimonial name: "Grace Hopper", role: "Rear Admiral", variant: :card, rating: 5 do %>
  <p>We shipped the <strong>whole</strong> migration without downtime.</p>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `name:` | string | required | |
| `role:` | string | none | |
| `avatar:` | URL or `nil` | none | Rendered through `avatar` with an initials fallback |
| `rating:` | 1–5 integer | none | `ArgumentError` outside 1..5 |
| `variant:` | `:plain`, `:card` | `:plain` | Validated |
| `size:` | `:default`, `:large` | `:default` | `:large` is a hero quote |

- The quote is a positional string or a block.
- Other options go on the `<figure>`.

## Markup

```html
<figure class="UnmagicTestimonial UnmagicTestimonial--card">
  <p class="UnmagicTestimonial__rating" role="img" aria-label="Rated 5 out of 5">
    <svg class="UnmagicIcon" aria-hidden="true">…star…</svg> ×5
  </p>
  <blockquote class="UnmagicTestimonial__quote"><p>…</p></blockquote>
  <figcaption class="UnmagicTestimonial__author">
    <span class="UnmagicAvatar">…</span>
    <span class="UnmagicTestimonial__name">Grace Hopper</span>
    <span class="UnmagicTestimonial__role">Rear Admiral</span>
  </figcaption>
</figure>
```

`<figure>`, `<blockquote>` and `<figcaption>` are the native quotation pattern.

## Accessibility

- The rating is a single `role="img"` with a spoken label, and its stars are
  `aria-hidden`.
- The avatar is decorative (`alt=""`) because the name is right beside it.
- Colour doesn't carry meaning; the stars are filled or outlined as well as
  coloured.

## Styling

- **Section:** `Testimonial`.
- **Elements:** `__quote`, `__rating`, `__author`, `__name`, `__role`.
- **Modifiers:** `--card` (surface, border, 0.75rem radius, like `UnmagicCard`)
  and `--large` (1.25rem quote).
- **Tokens:** `text`, `text-2`, `text-3`, `surface`, `border`.
- **Stars** use `--unmagic-rating`, a new theme token (accepted) falling back
  to `--color-amber-400, #fbbf24`. Its reason: the warn tone reads as a
  warning, not a star. It is shared with `feedback_form`. Add it to the README
  Theming list and give it a dark value in the preview layout's dark block.
- **Icons:** a `star` Lucide path added to `Icons::PATHS`.

## Behaviour (JavaScript)

_None._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.testimonial.rating` | "Rated %{rating} out of 5" |

## Specs

- `figure > blockquote` and `figcaption` hold the name and role.
- `--card` and `--large` classes appear.
- The rating has its label, and there are 5 star SVGs.
- `ArgumentError` for `rating: 6` and for an unknown `variant:`.
- A block's content lands in the blockquote.
- `class:` passes through.

## Preview

- **Page:** `marketing`, with a three-column grid of `:card` testimonials and a
  `:large` plain one.
- **Hand-check:** dark mode, and a screen reader reading the rating.

## Open questions

- Is a company logo slot (`logo:`) needed, or is `role:` enough?
