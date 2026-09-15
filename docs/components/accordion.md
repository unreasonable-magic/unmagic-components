# `disclosure` and `accordion`

> Status: draft
> Tier: 1 (no JS)
> Replaces or relates to: Rails Blocks "Accordion" and "Collapsible" (gap source);
> `menu` (also built on `<details>`); `tree_view`

## Purpose

- **`disclosure`** hides secondary content behind a toggle: "Advanced options"
  under a form, a stack trace under an error, the raw payload of a webhook
  delivery.
- **`accordion`** is a bordered stack of disclosures, such as an FAQ or a list
  of settings sections, optionally with only one open at a time.

It isn't for navigation between views (use `tabs`) or for actions (use `menu`).

## API

```erb
<%= disclosure "Advanced options" do %>
  <%= form.field :timeout, "Timeout (seconds)" %>
<% end %>

<%= disclosure "Raw payload", open: @delivery.failed? do %>
  <pre><%= @delivery.payload %></pre>
<% end %>

<%= accordion exclusive: true, id: "billing_faq" do |accordion| %>
  <% accordion.item "When am I charged?", open: true do %>…<% end %>
  <% accordion.item "Can I change plans?" do %>…<% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `summary` (positional) | String | — | Or a `summary:` block part for markup (see below) |
| `open:` | Boolean | `false` | Server-rendered open state |
| `exclusive:` (accordion) | Boolean | `false` | One item open at a time, via `<details name>` |
| `id:` (accordion) | String | random | Also names the exclusive group |

- **`accordion.item(summary, open: false, **options, &block)`**; the options
  go on its `<details>`.
- **Rich summaries** (a badge beside the title): the block form
  `disclosure do |d| d.summary { … } … end` captures the summary separately.
- **Validation:** an empty accordion renders nothing. With `exclusive: true`,
  more than one `open: true` item raises `ArgumentError`.
- **Other options** go on the `<details>` (`disclosure`) or the wrapper `<div>`
  (`accordion`).

## Markup

```html
<details class="UnmagicDisclosure">
  <summary class="UnmagicDisclosure__summary">
    <svg class="UnmagicIcon UnmagicDisclosure__chevron" aria-hidden="true">…chevron_right…</svg>
    <span class="UnmagicDisclosure__title">Advanced options</span>
  </summary>
  <div class="UnmagicDisclosure__panel">…</div>
</details>

<div class="UnmagicAccordion" id="billing_faq">
  <details class="UnmagicDisclosure UnmagicDisclosure--in-accordion" name="billing_faq" open>
    <summary class="UnmagicDisclosure__summary">
      <span class="UnmagicDisclosure__title">When am I charged?</span>
      <svg class="UnmagicIcon UnmagicDisclosure__chevron" aria-hidden="true">…chevron_down…</svg>
    </summary>
    <div class="UnmagicDisclosure__panel">…</div>
  </details>
</div>
```

- **Native `<details>`/`<summary>`:** toggling, keyboard support and state
  exposure come free.
- **Exclusivity:** the shared `name` attribute is the platform's own
  one-at-a-time behaviour. In a browser without it, items simply open
  independently, which is harmless.
- **Chevron placement:** leading `chevron_right` for a disclosure (it reads like
  a tree toggle), trailing `chevron_down` for an accordion row. The same
  convention as `menu`'s trigger.

## Accessibility

- **Pattern:** follows the APG
  [Disclosure](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/) pattern,
  natively. `<summary>` is exposed as a button with expanded state.
- **Keyboard:** Tab to a summary, Enter or Space toggles. It deliberately has no
  arrow-key roving between accordion headers: that is optional in the APG
  accordion pattern and needs script.
- **Headings:** a summary isn't a heading. An FAQ that wants headings in the
  outline passes `d.summary { tag.h3 … }`. Some screen readers drop heading
  semantics inside `<summary>`; see open questions.
- **Icons:** chevrons are `aria-hidden`.

## Styling

CSS sections: `Disclosures` and `Accordions`.

- **Elements:**
  - `UnmagicDisclosure`, with `__summary`, `__chevron`, `__title`, `__panel`
    and `--in-accordion`
  - `UnmagicAccordion`
- **State** is `[open]`: the chevron rotates 90° (disclosure) or 180°
  (accordion).
- **Summary:**
  - `list-style: none`, with the `::-webkit-details-marker` hidden, as
    `.UnmagicMenu__trigger` does.
  - `inline-flex`, `gap: 0.375rem`, 0.875rem weight 500 in
    `neutral-600`/`dark:neutral-400`, turning `neutral-900`/`dark:neutral-100` on hover.
  - A `:focus-visible` ring.
- **Panel:** `padding-top: 0.5rem`.
- **Accordion:**
  - A `white`/`dark:neutral-900` box with a `neutral-200`/`dark:neutral-800` border and radius
    0.5rem.
  - Items are divided by a top border (`--in-accordion + --in-accordion`).
  - The summary is `flex`, full width, `padding: 0.75rem 1rem`, with
    `justify-content: space-between`.
  - The panel has `padding: 0 1rem 1rem`.
- **Open/close animation** is progressive enhancement, where supported:
  `interpolate-size: allow-keywords` with a `::details-content` height and
  opacity transition of 150ms.
- **Reduced motion:** the chevron rotation transition and the content
  transition are off.
- Palette colours with `dark:` variants only.

## Behaviour (JavaScript)

_None. CSS and markup only._

A morph refresh resets `open` to the server's value. That is correct for the
server's view of the page, but it does lose a toggle the user made. See open
questions.

## I18n

None: the gem prints no words of its own.

## Specs

- **Disclosure:** `details.UnmagicDisclosure > summary.UnmagicDisclosure__summary`
  contains an `aria-hidden` `svg` and a `.UnmagicDisclosure__title` with the
  text. The panel holds the block, and `open:` sets the `open` attribute.
- **Rich summary:** the `summary` block part renders its markup inside the
  `<summary>`.
- **Accordion:**
  - wrapper `.UnmagicAccordion`, each item `UnmagicDisclosure--in-accordion`
  - `exclusive: true` → every `details` has `name` equal to the id, or to a
    shared generated value when there is no id
  - without it, no `name`
- **Validation:** exclusive with two `open: true` items raises `ArgumentError`.
- **Passthrough:** `class:` and `data:` reach the `details` and the wrapper.

## Preview

`primitives` page, `disclosure` and `accordion` sections:
- a disclosure around form fields
- an open disclosure with a `<pre>`
- an accordion FAQ with `exclusive: true`
- a non-exclusive accordion with a badge in a rich summary

**Check by hand:**
- Opening one exclusive item closes the other.
- Keyboard toggling works.
- Chevron rotation, and no animation under reduced motion.
- The dark theme.
- The morph behaviour: toggle an item, submit a form on the page, and confirm
  the item resets.

## Open questions

- **Remembering user toggles.** Should an `id:`ed disclosure remember toggles
  across morphs, as `tabs` does with `sessionStorage`? That makes it a Tier 2
  element. Proposal: not now; revisit when an app asks.
- **Headings inside `<summary>`.** Should `accordion` accept `heading: 3` and
  render `h3 > summary`-equivalent markup? That means dropping `<details>` for
  the APG button pattern, which needs JS. Proposal: document the trade-off and
  keep `<details>`.
