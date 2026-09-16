# `avatar` and `avatar_group`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Avatar" (gap source); `page_header`'s
> `leading { }` slot; `skeleton_circle`

## As built

Where the build differs from this note:

- The tint is picked with `unmagic-color`'s stable string hash (BKDR) rather than `Zlib.crc32`; the gem depends on unmagic-color for this.
- Specs are in `icons_avatar_spec.rb`, and the preview has its own Avatar page.

## Purpose

A person's or organisation's picture, falling back to their initials when there
is no image. A view reaches for it:
- in a table's name column
- beside a comment
- in a page header's `leading` slot
- as a stack of people on a card ("who can see this")

It is not for logos or arbitrary images; use an `<img>` for those.

## API

```erb
<%= avatar "Ada Lovelace" %>
<%= avatar @user.name, src: @user.avatar_url, size: :large %>
<%= avatar "Acme Ltd", shape: :square %>
<%= avatar @user.name, skeleton: true %>

<%= avatar_group max: 3, size: :small do |group| %>
  <% @members.each do |member| %>
    <% group.avatar member.name, src: member.avatar_url %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `name` (positional) | String | — | Required. Gives the initials and the accessible name |
| `src:` | URL or `nil` | `nil` | Blank falls back to initials |
| `size:` | `:small`, `:medium`, `:large` | `:medium` | 1.5rem, 2rem, 2.5rem. Validated |
| `shape:` | `:circle`, `:square` | `:circle` | Square is for organisations. Validated |
| `tint:` | Boolean | `true` | Initials sit on one of six palette tints, picked from the name |
| `skeleton:` | Boolean | `false` | Renders a `skeleton_circle` of the same size |
| `max:` (group) | Integer or `nil` | `nil` | Avatars beyond it collapse into a "+N" counter |

- **Initials:** the first letter of the first and last words, upcased (for
  example "Ada Lovelace" → "AL", "Plato" → "P"). A blank name renders an em dash
  in place of initials, with no accessible name.
- **Tint:**
  - The name's normalised form (squished, downcased) is hashed with
    `Zlib.crc32`, and the result modulo 6, plus 1, picks
    `UnmagicAvatar--tint-N`. The same person always gets the same colour, on
    every page and every server.
  - `tint: false` uses the neutral surface instead. A blank name is always
    neutral.
- **The group** passes `size:` and `shape:` to every avatar in it. A size given
  on `group.avatar` itself raises `ArgumentError`, so a stack never mixes sizes.
- **Other options** go on the root `<span>` (`avatar`) or `<div>`
  (`avatar_group`).

## Markup

```html
<span class="UnmagicAvatar UnmagicAvatar--medium" role="img" aria-label="Ada Lovelace" title="Ada Lovelace">
  <span class="UnmagicAvatar__initials" aria-hidden="true">AL</span>
  <img class="UnmagicAvatar__image" src="/ada.png" alt="" loading="lazy" decoding="async">
</span>

<div class="UnmagicAvatarGroup UnmagicAvatarGroup--small" role="group" aria-label="5 people">
  <span class="UnmagicAvatar UnmagicAvatar--small" role="img" aria-label="Ada Lovelace">…</span>
  …
  <span class="UnmagicAvatarGroup__more" title="Grace Hopper, Katherine Johnson">+2</span>
</div>
```

- The initials always render. The image sits on top of them, so if it fails to
  load (a broken image with `alt=""` shows nothing), the initials show through
  without any script.
- `role="img"` with `aria-label` makes the pair one named graphic.
- The "+N" counter's `title` lists the hidden names.

## Accessibility

- **Name:** each avatar is `role="img"` with the person's name. When the name is
  already shown in text beside the avatar, the caller passes
  `"aria-hidden": true`. The note in the README says so.
- **Group:** `role="group"`, labelled with the count ("5 people", through I18n).
  The "+N" counter is plain text read in order.
- **Keyboard:** not interactive, so nothing is focusable. An avatar wrapped in
  `link_to` takes the link's focus ring.

## Styling

CSS section: `Avatars`.

- **Elements and modifiers:**
  - `UnmagicAvatar`, with `--small`, `--medium`, `--large` and `--square`
  - `__initials` and `__image`
  - `UnmagicAvatarGroup`, with the size modifiers and `__more`
- **Layout:**
  - The avatar is `inline-grid` with `place-items: center`, and both children
    sit in the same grid cell.
  - The image uses `object-fit: cover` and `border-radius: inherit`.
  - Sizes set `width`, `height` and the initials' `font-size` (0.625rem,
    0.75rem, 0.875rem), and match `skeleton_circle`'s `size:`.
- **Colour:**
  - Neutral (`tint: false`): initials in `neutral-600`/`dark:neutral-400` on
    `neutral-100`/`dark:neutral-800`.
  - Tinted: `UnmagicAvatar--tint-1` … `--tint-6` each pair a palette hue's
    light tint with a dark counterpart, chosen for readable initials:
    - 1: `bg-sky-100 text-sky-700 dark:bg-sky-400/15 dark:text-sky-300`
    - 2: `bg-emerald-100 text-emerald-700 dark:bg-emerald-400/15 dark:text-emerald-300`
    - 3: `bg-amber-100 text-amber-700 dark:bg-amber-400/15 dark:text-amber-300`
    - 4: `bg-rose-100 text-rose-700 dark:bg-rose-400/15 dark:text-rose-300`
    - 5: `bg-violet-100 text-violet-700 dark:bg-violet-400/15 dark:text-violet-300`
    - 6: `bg-teal-100 text-teal-700 dark:bg-teal-400/15 dark:text-teal-300`
  - The square shape uses radius 0.375rem.
- **Tint colours (accepted)** are palette choices, not theme variables. A host
  recolours them by overriding those palette colours in its `@theme`, or by
  overriding `UnmagicAvatar--tint-N` in its own CSS.
- **Group:**
  - Overlap with a negative inline margin (−0.375rem at small).
  - A 2px ring in `white`/`dark:neutral-900` (box-shadow) separates the faces.
  - `__more` has the same box as an avatar, in `neutral-50`/`dark:neutral-800/50` with
    `neutral-500`.
- No motion.

## Behaviour (JavaScript)

_None. CSS and markup only._

## I18n

| Key | Default |
|---|---|
| `unmagic.components.avatar.group` | "%{count} people" |
| `unmagic.components.avatar.more` | "+%{count}" |

## Specs

`spec/unmagic/components/primitives_spec.rb` (or a new `avatar_spec.rb`):

- **Initials:**
  - "Ada Lovelace" → `.UnmagicAvatar__initials` text "AL"
  - "Plato" → "P"
  - "  ada   byron lovelace " → "AL"
- **With `src:`:** `img.UnmagicAvatar__image[alt=""][src]` follows the
  initials. Without `src:`, or with a blank one, there is no `img`.
- **Root:** `role="img"` and `aria-label` equal to the name. `class:` and
  `data:` pass through.
- **Validation:** `size: :huge` and `shape: :blob` raise `ArgumentError` with
  `unknown avatar size :huge`.
- **Tint:**
  - "Ada Lovelace" gets exactly one `UnmagicAvatar--tint-N` class, with N
    between 1 and 6.
  - "ada  lovelace" gets the same N.
  - `tint: false` and a blank name get no tint class.
- **Skeleton:** `skeleton: true` renders `.UnmagicSkeleton--circle` with a width
  matching the size.
- **Group:**
  - `max: 2` with 4 avatars → 2 `.UnmagicAvatar` elements plus
    `.UnmagicAvatarGroup__more` "+2", whose `title` lists the other two names
  - `aria-label` is "4 people"
  - a `size:` on `group.avatar` raises

## Preview

`primitives` page, `avatar` section:
- the three sizes, with and without an image
- a row of names showing all six tints, and one `tint: false`
- a broken `src`, to show the fallback
- the square shape
- a group of 6 with `max: 3`
- an avatar in `page_header`'s `leading`

**Check by hand:**
- Initials contrast on every tint, in light and dark (with the preview's dark
  tint values).
- The group ring against the card surface.
- A broken image shows the initials.

## Open questions

- **A presence dot** (`status: :good`) is left out until an app needs it.
