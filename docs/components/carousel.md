# `carousel`

> Status: draft
> Tier: 3 (large)
> Replaces or relates to:
> - Rails Blocks "Carousel" (the gap source)
> - `lightbox` (a slide can open one), `tabs` (roving selection), `card`

## Purpose

A row of slides the reader moves through one at a time: onboarding screens,
screenshots of an integration, a set of plan cards on a narrow screen. The
slides sit in a scroll-snapping track, so swiping, trackpads and scrollbars
work natively. Buttons and indicators are added on top.

It is **not** for hiding important content behind navigation, and not for
auto-rotating banners. **No autoplay (decided).** Autoplay needs a pause
control, pausing on hover and focus, and turning off under reduced motion. It
also moves content the reader hasn't asked for, which is at odds with the
gem's application-UI focus.

## API

```erb
<%= carousel label: "Screenshots", per_view: 1, indicators: true do |c| %>
  <% c.slide do %><%= image_tag "setup-1.png", alt: "Connect your repository" %><% end %>
  <% c.slide label: "Invite your team" do %>…<% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `label:` | string | required | Names the carousel (`aria-label`); raises `ArgumentError` if blank |
| `per_view:` | 1, 2, 3, or `:auto` | 1 | Validated. `:auto` means slides size themselves |
| `indicators:` | boolean | `true` when `per_view` is 1 | The row of dots |
| `loop:` | boolean | `false` | Next on the last slide goes to the first |
| `slide` `label:` | string | "N of M" (I18n) | The slide's accessible name |

- Other options go on the element.
- Zero slides render nothing.
- One slide renders the track with no controls.

## Markup

```html
<unmagic-carousel class="UnmagicCarousel UnmagicCarousel--per-1" loop>
  <section aria-roledescription="carousel" aria-label="Screenshots">
    <div class="UnmagicCarousel__controls">
      <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicCarousel__prev"
              aria-controls="unmagic_carousel_ab12_track" aria-label="Previous slide">…</button>
      <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicCarousel__next"
              aria-controls="unmagic_carousel_ab12_track" aria-label="Next slide">…</button>
    </div>
    <div id="unmagic_carousel_ab12_track" class="UnmagicCarousel__track" tabindex="0" aria-live="polite">
      <div class="UnmagicCarousel__slide" role="group" aria-roledescription="slide" aria-label="1 of 4">…</div>
      …
    </div>
    <div class="UnmagicCarousel__indicators">
      <button type="button" class="UnmagicCarousel__dot" aria-label="Go to slide 1" aria-current="true"></button>
      …
    </div>
  </section>
</unmagic-carousel>
```

- **Native base:** the track is
  `overflow-x: auto; scroll-snap-type: x mandatory`, and each slide has
  `scroll-snap-align: start`. Without script the reader swipes or scrolls.
- **Before upgrade:** the controls and indicators are hidden with
  `unmagic-carousel:not(:defined)`, so dead buttons never show.
- **Ids:** they come from `id:`, or `unmagic_carousel_<hex>` (as in `tabs.rb`).
- **Icons:** new Lucide `chevron_left` and `chevron_right` paths in
  `Icons::PATHS`.

## Accessibility

- **Pattern:** APG Carousel, the basic variant with previous/next buttons and
  a "picker" of buttons, without rotation controls. Slides are
  `role="group"` with `aria-roledescription="slide"`, and the wrapper is
  `aria-roledescription="carousel"`.
- **Live region:** the track is `aria-live="polite"`, so a button-driven change
  announces the new slide. It is set to `off` during a pointer scroll, to avoid
  chatter.
- **Keyboard:**

| Key | Where | Does |
|---|---|---|
| Tab | anywhere | Moves to prev, next, the track, then the indicators |
| Enter / Space | prev / next / dot | Moves to that slide |
| Arrow Left / Right | track focused | Previous / next slide |
| Home / End | track focused | First / last slide |

- **Focus:** it stays on the control pressed. Slides aren't focusable, but
  content inside them is. Off-screen slides are **not** made `inert`, because
  scroll-snap readers may reach them by scrolling. Instead, links in off-screen
  slides get `tabindex="-1"`, restored when visible.
- **At the edges:** prev on the first slide and next on the last get
  `aria-disabled="true"` (not `disabled`, which drops focus) when `loop` is
  false.

## Styling

- **CSS section `Carousels`.**
  - Elements: `__track`, `__slide`, `__controls`, `__prev`, `__next`,
    `__indicators`, `__dot`.
  - Modifiers: `--per-1`, `--per-2`, `--per-3` and `--per-auto`, which set
    `--unmagic-carousel-per-view` to the slide `flex-basis` via
    `calc((100% - gaps) / n)`.
- **Track:** `gap: 1rem`, `scrollbar-width: none` once upgraded (`:defined`),
  visible before, and `overscroll-behavior-x: contain`.
- **State:**
  - `.UnmagicCarousel__dot[aria-current="true"]` fills with `--unmagic-text`.
  - Other dots use `--unmagic-border-strong`.
  - `[aria-disabled="true"]` sits at 0.4 opacity.
- **Focus:** the standard `:focus-visible` outline on the track and buttons.
- **Motion:** `scroll-behavior: smooth` on the track, switched to `auto` under
  reduced motion.
- **No new tokens.** `--unmagic-carousel-per-view` is internal, not a theme
  token.

## Behaviour (JavaScript)

`<unmagic-carousel>` in `carousel.js`. It reads the `loop` attribute.

- **Moving:** prev, next and dot clicks go through `goTo(index)`, which calls
  `track.scrollTo({ left: slide.offsetLeft, behavior })`. `behavior` is
  `"auto"` under reduced motion. Keyboard handling sits on the track.
- **The current slide:**
  - An IntersectionObserver on the slides, rooted at the track with threshold
    0.6, tracks it.
  - On change it updates the dots' `aria-current`, the edge `aria-disabled`
    states, and the off-screen link `tabindex`.
  - It fires `unmagic-carousel:change` with `{ index }`.
- **Listeners:** element listeners are added in the constructor. The observers
  are created in `connectedCallback` and disconnected in
  `disconnectedCallback`.
- **Slides added or removed:** a MutationObserver on the track's `childList`
  re-observes the slides, relabels "N of M", and rebuilds the dots, cloning the
  first server-rendered dot as a template.

Turbo:
- **Cache:** on `turbo:before-cache` it scrolls the track to 0 and resets state
  to the server's markup (dot 1 current, prev disabled). `scrollLeft` isn't
  kept in snapshots, so this keeps the state attributes truthful.
- **Snapshot clones:** there is no generated DOM, except dots rebuilt after a
  mutation, and those match what the server would render. Connect re-derives
  the state from the scroll position.
- **Morph:** Idiomorph may reset `aria-current` and `tabindex` to the server's
  values. On `turbo:morph` the element re-syncs from the actual scroll
  position.
- **Streamed content:** a streamed `append` into the track, or a replaced
  carousel, is handled by the MutationObserver and `connectedCallback`.

Dependencies: none, and it doesn't need Turbo.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.carousel.previous` | "Previous slide" |
| `unmagic.components.carousel.next` | "Next slide" |
| `unmagic.components.carousel.go_to` | "Go to slide %{number}" |
| `unmagic.components.carousel.slide` | "%{number} of %{count}" |

## Specs

In a new `carousel_spec.rb`:
- The structure: `section[aria-roledescription=carousel][aria-label]`, the
  track with an id, and slides `role=group` `aria-label="1 of 3"`.
- Prev and next `aria-controls` the track id, and prev is `aria-disabled`
  initially (without `loop`).
- Indicators: one dot per slide, the first `aria-current`. `indicators: false`
  omits them.
- `per_view: 2` renders `--per-2`. A single slide renders no controls or dots,
  and zero slides render nothing.
- A slide's `label:` overrides the name.
- `ArgumentError` for a blank `label:` and for `per_view: 5`.
- `class:` passes through.

## Preview

A new section on `elements`: screenshots (`per_view: 1`, dots) and plan cards
(`per_view: :auto`).

Hand checks:
- Swipe and trackpad scroll snap, and the dots follow.
- Keyboard: arrows on the focused track, and Home/End.
- VoiceOver announces "2 of 4" after next.
- Reduced motion jumps with no smooth scroll.
- `loop` wraps.
- Back restores it at slide 1 with consistent state.
- Narrow widths, and dark mode.

## Open questions

- **Indicator semantics:** should dots be a `tablist` (the APG tabbed variant),
  or buttons with `aria-current` (proposed)?
- **Peek:** should slides peek ("show part of the next slide") by default at
  `per_view: 1`?
