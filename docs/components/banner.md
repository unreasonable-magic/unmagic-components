# `banner`

> Status: draft
> Tier: 1 (CSS and markup), plus a small optional `<unmagic-banner>` for
> dismissing
> Replaces or relates to: Rails Blocks "Banner" (gap source); `callout` (the same
> tones, in place); `flash_toasts` (transient)

## Purpose

A notice across the full width of the page, about the whole app or account
rather than one thing on the page:
- scheduled maintenance
- "You're impersonating Ada"
- a trial ending in 3 days
- a failed payment

It sits at the top of the layout, above the page header.

How it differs from the other notices:
- **`callout`** states the condition of something in place.
- **`flash_toasts`** reports the result of an action, briefly.
- **A banner** persists until the condition ends, or until the viewer dismisses
  it.

## API

```erb
<%= banner "Scheduled maintenance on Sunday, 02:00–03:00 UTC.", tone: :info %>

<%= banner tone: :warn, dismissible: true, id: "trial_ending_#{@account.trial_ends_on}" do |banner| %>
  Your trial ends in <%= pluralize @account.trial_days_left, "day" %>.
  <% banner.action "Choose a plan", billing_path %>
<% end %>

<%= banner "You're signed in as Ada Lovelace.", tone: :accent do |banner| %>
  <% banner.action "Stop impersonating", impersonation_path, method: :delete %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `content` (positional) | String | `nil` | Or a block |
| `tone:` | `:neutral`, `:info`, `:good`, `:warn`, `:bad`, `:accent` | `:neutral` | Validated. `:accent` is the filled, high-emphasis style |
| `icon:` | Boolean | `true` | The tone's icon from `Icons::TONE_ICONS`; none for neutral or accent |
| `dismissible:` | Boolean | `false` | Needs `id:`; without one it raises `ArgumentError` |
| `dismiss_url:` | URL or `nil` | `nil` | Also POSTs the dismissal to the host, so it follows the user across devices. Implies `dismissible: true`; still needs `id:` |

- **`banner.action`** takes `link_to`'s arguments. With `method:` other than GET
  it renders `button_to`, as `menu.button` does. The action renders as a text
  link styled for the tone.
- **Dismissal identity:** the `id:` is also the dismissal key. Put the
  condition in the id (for example the trial's end date), so a new condition
  shows again.
- **Where dismissals are remembered (decided):**
  - By default, in the browser: `localStorage`, keyed by `id:`. It needs no
    route in the host.
  - With `dismiss_url:`, the browser remembers it *and* the element POSTs
    `{ id }` to that URL. The host records it and stops rendering the banner
    for that user, on any device. The host should skip rendering a banner it
    knows is dismissed; the element can only hide one that was sent.
- **Other options** go on the root.

## Markup

```html
<unmagic-banner class="UnmagicBanner UnmagicBanner--warn" id="trial_ending_2026-09-19" role="region" aria-label="Announcement">
  <svg class="UnmagicIcon UnmagicBanner__icon" aria-hidden="true">…triangle_alert…</svg>
  <div class="UnmagicBanner__content">
    Your trial ends in 3 days.
    <a class="UnmagicBanner__action" href="/billing">Choose a plan</a>
  </div>
  <button type="button" class="UnmagicButton UnmagicButton--icon UnmagicBanner__dismiss"
          data-unmagic-banner-dismiss aria-label="Dismiss" title="Dismiss">…x…</button>
</unmagic-banner>
```

- **Which root element:** a non-dismissible banner renders a plain
  `<div class="UnmagicBanner">` with no dismiss button. Only
  `dismissible: true` uses the custom element.
- **No `role="banner"`.** That role is the page's header landmark, so it would
  be wrong here. A labelled `region` lets people jump to it.

## Accessibility

- **Landmark:** `role="region"` plus `aria-label` from I18n ("Announcement").
  A `:bad` banner uses `role="alert"` only when it is streamed in, not on page
  load; see open questions.
- **Meaning:** the tone icon plus text carries it, never colour alone.
- **Dismiss button:** a labelled icon button. After dismissing, focus moves to
  `<main>`, or to `document.body` when there is none, so it isn't lost.
- **Actions:** ordinary links and buttons.

## Styling

CSS section: `Banners`.

- **Elements and modifiers:** `UnmagicBanner`, with tone modifiers, `__icon`,
  `__content`, `__action` and `__dismiss`.
- **Root:**
  - `flex`, `align-items: center`, `gap: 0.75rem`,
    `padding: 0.625rem 1rem`, 0.875rem type.
  - No radius and no side borders, so it bleeds edge to edge.
  - A bottom border.
- **Tones** reuse callout colours:
  - good: `green-50`/`dark:green-400/10` with a `green-200`/`dark:green-400/30` border
  - warn: `amber-50`/`dark:amber-400/10` with an `amber-200`/`dark:amber-400/30` border
  - bad: `red-50`/`dark:red-400/10` with a `red-200`/`dark:red-400/30` border
  - info: `neutral-50`/`dark:neutral-800/50`
  - neutral: `neutral-100`/`dark:neutral-800`
  - accent: `neutral-900`/`dark:white` with `white`/`dark:neutral-900`
- **Action:** `font-weight: 500`, underlined, `color: inherit`.
- **Dismiss button:** `margin-left: auto`, `color: inherit`.
- **Before the element upgrades:**
  `unmagic-banner:not(:defined) .UnmagicBanner__dismiss { display: none }`,
  so a dismiss that can't work never shows.
- Palette colours with `dark:` variants only, and no motion.

## Behaviour (JavaScript)

`<unmagic-banner>`, in `banner.js`, only for `dismissible: true`.

This is the one piece of script in an otherwise Tier 1 component, and it is
kept out of the common case (no dismissal). **Why it's needed:** remembering a
dismissal across pages needs either a request or client storage. Client
storage keeps it working with no route in the host app.

- **Click on `[data-unmagic-banner-dismiss]`:**
  - fire `unmagic-banner:dismiss`, cancelable, with
    `detail: { id, url }`. A host that calls `preventDefault` takes over
    entirely, and nothing below happens.
  - store `id` in `localStorage` under `unmagic-banner:dismissed`, a JSON array
    capped at 50 ids. The write is wrapped in `try`, because storage can throw
    in a private window; the banner still hides.
  - set `hidden`
  - if the element has a `dismiss-url` attribute (rendered from
    `dismiss_url:`), `fetch` it with `method: "POST"`, `keepalive: true`, the
    `X-CSRF-Token` from `meta[name=csrf-token]`, and a form-encoded `id`. This
    needs no Turbo. On failure it fires `unmagic-banner:dismiss-error`; the
    banner stays hidden for this browser.
- **`connectedCallback`:** if the id is stored, set `hidden` at once. The
  module is preloaded, so this runs before first paint in practice.
- **`turbo:morph`:** re-apply `hidden`, since the morph restores the server
  markup.
- **Turbo cache:** nothing to reset; a hidden banner stays hidden in the
  snapshot, which is correct.
- **Dependencies:** none, and no Turbo requirement.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.banner.label` | "Announcement" |
| `unmagic.components.banner.dismiss` | "Dismiss" |

## Specs

- **Plain banner:** `banner "…", tone: :warn` → `div.UnmagicBanner.UnmagicBanner--warn[role=region][aria-label=Announcement]`
  with `svg.UnmagicBanner__icon`, and no dismiss button.
- **Dismissible:** `dismissible: true, id: "x"` → `unmagic-banner#x` with
  `button[data-unmagic-banner-dismiss][aria-label=Dismiss]`, and no
  `dismiss-url` attribute. `dismissible: true` without an `id:` raises
  `ArgumentError`.
- **Server dismissal:** `dismiss_url: "/dismissals", id: "x"` →
  `unmagic-banner#x[dismiss-url="/dismissals"]` with the dismiss button, even
  without `dismissible: true`. `dismiss_url:` without `id:` raises
  `ArgumentError`.
- **Actions:** `banner.action` with a GET renders
  `a.UnmagicBanner__action`. With `method: :delete` it renders a form button
  with that class.
- **Icons:** `tone: :accent` and `:neutral` have no icon, and `icon: false`
  drops it.
- **Validation:** `tone: :loud` raises `unknown banner tone :loud`.

## Preview

The `toasts` page, renamed "Notices", or a new `banners` page. It shows:
- one banner of each tone stacked
- a dismissible banner with an action, plus a "reset dismissals" button that
  clears `localStorage`

**Check by hand:**
- The dismissal survives a Turbo visit and a reload.
- A morph refresh keeps it hidden.
- Focus after dismissing.
- The dark theme, especially accent.
- No dismiss button flashes with JS disabled.

## Open questions

- **Announcing live banners.** Should a banner streamed in (for example
  "Deploy failed") announce itself with `role="alert"`, and if so, through an
  explicit `live: true` option rather than inferring it from the tone?
