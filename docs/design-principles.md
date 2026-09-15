# Design principles

How a component in unmagic-components is built. The rules here are drawn from
the components that already ship; each cites a file that does it this way.
Read this before designing a component. Write the component's design note in
[`docs/components/`](components/) before writing its code.

## What the gem is

Server-rendered UI for Rails views, in the spirit of `form_for`. A view
describes what it wants (the columns, the items, the tabs) and the gem draws
the chrome around it. The audience is application UI (admin screens, settings,
index and detail pages), not marketing pages.

## Philosophy

1. **The server renders the whole thing.** The markup that leaves Ruby is
   complete and correct: roles, ARIA state, the selected tab, the hidden panels,
   a formatted time. JavaScript only moves state around afterwards. A component
   is usable, or at least readable, before its script loads.
   - `tabs.rb` renders the full ARIA tab pattern, and `tabs.js` only moves the
     selection.
   - `local_time.rb` renders the time in `Time.zone` until `<unmagic-time>`
     reformats it.
   - A tooltip's term already looks like a term before it upgrades
     (`.UnmagicTooltip--term`).

2. **Native elements first.** Reach for what the platform already does before
   writing behaviour: `<details>` for disclosure (`menu.rb`), `<dialog>` for
   modals (`dialog.rb`), the Popover API and top layer for things that must not
   be clipped (`tooltip.js`, `toasts.js`), and form `reset` events
   (`autogrow.js`, `uuid_input.js`). Script fills the gaps the native element
   leaves, and its header comment says which gaps.

3. **No Tailwind, no Stimulus, no host helpers.** Tailwind doesn't scan
   installed gems, so a utility class written in this gem's Ruby would render
   unstyled in the host (`components.css` header, `engine.rb`). Behaviour is
   plain custom elements. Icons are inline SVG (`icons.rb`), so there is no
   icon library. The only runtime dependencies are ActiveSupport, ActionView
   and Railties (`unmagic-components.gemspec`). Turbo is optional unless a
   component documents that it needs it.

4. **Seams, not options, for what the app owns.** When an app will already
   have its own version of something (an empty state, a pager, a submit
   button's classes), expose a callable on `Configuration` with a working
   default rather than growing options. See `configuration.rb`.

5. **Built for Hotwire.** Every component survives a Turbo cache restore, a
   morph refresh, a permanent element being moved and content streamed in
   later. This is a design constraint, not a test afterthought. See the
   JavaScript section below.

6. **Themeable, not themed.** One layer of `--unmagic-*` custom properties with
   Tailwind-palette fallbacks. The gem ships no dark mode: the host's tokens
   flip, and the gem's tokens flip with them.

7. **Small surface, sharp defaults.** A component does the common case with no
   options. Enumerated options are few and validated. Anything else a caller
   passes lands on the root element.

## Ruby

### Files

- `lib/unmagic/components/<name>.rb`, requiring it from
  `lib/unmagic/components.rb` before `action_view_helpers`.
- Collaborators live in a folder named after the component
  (`table/column.rb`, `detail_list/item.rb`).

### Class shape

There is no base class. See `tooltip.rb` and `menu.rb`.

```ruby
module Unmagic
  module Components
    # One line saying what it is. See ActionViewHelpers#thing.
    class Thing
      SIZES = %i[small medium large].freeze

      def initialize(view, size:, **options)
        unless SIZES.include?(size)
          raise ArgumentError, "unknown thing size #{size.inspect} (expected one of #{SIZES.inspect})"
        end

        @view = view
        @size = size
        @options = options
      end

      def render(content)
        view.content_tag(:div, content, **@options, class: view.class_names("UnmagicThing", "UnmagicThing--#{@size}", @options[:class]))
      end

      private

      attr_reader :view

      delegate :tag, :safe_join, to: :view, private: true
    end
  end
end
```

- **`view` comes first, then keyword options.** The class renders through the
  view (`content_tag`, `tag`, `class_names`, `capture`, `link_to`). It never
  builds HTML strings by hand.
- **Enumerated options are validated against a frozen constant**, raising
  `ArgumentError` with the message
  `unknown <component> <option> :value (expected one of [...])`. Specs match on
  it.
- **Class-only components** (a look that composes with Rails' own tags) are a
  module with `self.classes`. See `button.rb` and `badge.rb`.
- **Mark-up that isn't user input** and must be `html_safe` gets a
  `rubocop:disable Rails/OutputSafety` with a reason (`icons.rb`).

### Builders

A component made of parts yields a builder, the way `form_for` yields `f`
(`menu.rb`, `tabs.rb`, `card.rb`, `detail_list.rb`):

- Part methods (`menu.link`, `tabs.tab`, `card.footer`) **record and return
  `nil`**, so `<% %>` and `<%= %>` both behave.
- `render` runs once, after the block, when it has seen every part. It
  validates combinations there, e.g. `tabs.rb` raises when the counts of
  enabled tabs and panels don't match.
- A part that takes markup takes a block and captures it with
  `view.capture(&block)`.

### Helpers

Every component is reached through a helper in `action_view_helpers.rb`. The
helper stays thin and the class does the work:

```ruby
def menu(label = nil, align: :end, **options, &block)
  builder = Components::Menu.new(self, label: label, align: align, **options)
  capture(builder, &block)
  builder.render
end
```

- **Content** is a positional argument or a block
  (`block ? capture(&block) : content`). See `badge`, `callout` and
  `empty_state`.
- **Other options go on the root element.** Merge `class:` with
  `class_names("UnmagicThing", options[:class])`, gem classes first. `id:`
  belongs to the root unless the helper documents otherwise, as `table_for`
  does.
- **The comment above the helper is the API documentation.** It gives:
  - an ERB example
  - every option and its default
  - "Other options go on the …"
  - what happens with blank input
  - `Needs import "unmagic/components/<name>"` when there is script
- **Form controls** are methods on `FormBuilder` and must work as a `field`'s
  control via `as:`. Where it makes sense they get a matching `_tag` helper for
  use outside a builder, e.g. `autogrow_text_area` / `autogrow_text_area_tag`
  and `uuid_field` / `uuid_input_tag`.
- **Blank values render an em dash** where a value is expected
  (`detail_list`, `local_time_tag`).
- **Skeletons.** A component that stands in for loaded content accepts
  `skeleton: true` and renders its own skeleton, as `detail_list`, `card` and
  `page_header` do.

### Words

- Every word the gem prints goes through
  `I18n.t("unmagic.components.<component>.<key>", default: "English")`. The
  English default lives in the call; there is no locale file (`menu.rb`,
  `copy_button.rb`).
- Document the key in the README section for the component.

### Ids and ARIA wiring

- When parts must reference each other (`aria-controls`, `aria-labelledby`),
  derive ids from the caller's `id:`. Fall back to a random base
  (`"unmagic_<name>_#{SecureRandom.hex(4)}"`), as in `tabs.rb`.
- Ids that script creates use a module-level counter (`tooltip.js`).

### Icons

- Use `Icons.svg(view, :name)`. A new glyph is a Lucide path added to
  `Icons::PATHS`: inline, ISC-licensed, and `aria-hidden` by default.
- Tone icons come from `Icons::TONE_ICONS`.

## CSS

All styles live in `app/assets/stylesheets/unmagic/components.css`.

- **One section per component**, opened with the same right-aligned dash
  banner the others use (`/* ---- Tooltips */`). Place it next to related
  sections.
- **Naming** is BEM with a PascalCase block: `UnmagicTooltip`,
  `UnmagicTooltip__popup`, `UnmagicTooltip--term`. Everything is prefixed, so
  nothing collides with host classes.
- **State is styled from attributes the markup already carries**: ARIA or
  `data-*`, not state classes. For example `[aria-selected="true"]`,
  `[aria-current="page"]`, `[data-open]`, `[data-copied]`, `[hidden]`
  (`Tabs`, `Tooltips`, `Clipboard`). The markup, the accessibility tree and the
  look then can't disagree.
- **Every colour is a token with a fallback:**
  `var(--unmagic-border, var(--color-neutral-200, #e5e5e5))`.
  - Reuse the existing tokens: surface, surface-2/3, raised, hover, border,
    border-strong, text, text-2/3, accent, on-accent, good/warn/bad and their
    surface and border variants, tooltip, focus, backdrop, skeleton.
  - A new token needs a reason. Add it to the README's Theming list and to the
    dark block in `preview/views/layouts/preview.html.erb`.
- **Theme tokens and per-component knobs are different things.**
  - A *theme token* is a colour or surface the host sets once for its whole
    theme (`--unmagic-border`). New ones need a reason, a README entry and a
    dark value in the preview.
  - A *knob* is a per-instance custom property the component's Ruby writes
    through `style:`, e.g. `--unmagic-marquee-duration` and
    `--unmagic-carousel-per-view`. Knobs are named
    `--unmagic-<component>-<property>`, documented only in that component's
    README section, and never listed under Theming.
  - Before adding a token, prefer an existing one: a switch thumb can be
    `--unmagic-raised`, and a lightbox backdrop `--unmagic-backdrop`.
- **No dark variant, no theme selectors.** See the stylesheet header.
- **Scale.** Match the existing components rather than inventing values:
  - Type: 0.875rem/1.25rem for body text, 0.75rem/1rem for small labels.
  - Radii: 0.375rem (items), 0.5rem (panels), 0.75rem (cards and tables).
  - Shadows: the existing tailwind-shaped `box-shadow` values.
  - Spacing in rem.
- **Focus** is
  `:focus-visible { outline: 2px solid var(--unmagic-focus, …); outline-offset: 2px }`.
- **Motion** is short (100–200ms), and every movement (translate, scale,
  rotate, scroll animation) is switched off under
  `@media (prefers-reduced-motion: reduce)`. An indicator that would otherwise
  look frozen may keep a slow opacity change in place of the movement, e.g. a
  spinner pulses instead of rotating.
- **Defend against host globals** where a host's bare-element rules are likely
  to leak in. Reset `margin` on links in a `<nav>` (`Tabs`), and type styles in
  top-layer content (`Tooltips`).
- **Visually hidden** text uses `UnmagicVisuallyHidden`.
- **Comments explain why** a rule exists, especially a workaround. See the
  `.UnmagicTable tbody tr` border comment.

## JavaScript

One custom element per file, in `app/assets/javascripts/unmagic/components/`.
`config/importmap.rb` pins it automatically. Add an import line to
`app/assets/javascripts/unmagic/components.js`.

```js
// <unmagic-thing value="…"> — one line saying what it is, rendered by `thing`.
//
// What the native markup already does, and what this element adds to it. The
// attributes it reads, the events it fires, what it needs (Turbo?).

class UnmagicThing extends HTMLElement {
  #timer = null

  constructor() {
    super()
    // On the element itself, once, so moving it never doubles them up.
    this.addEventListener("click", this.#clicked)
  }

  connectedCallback() {
    document.addEventListener("turbo:before-cache", this.#beforeCache)
  }

  disconnectedCallback() {
    document.removeEventListener("turbo:before-cache", this.#beforeCache)
    clearTimeout(this.#timer)
  }

  #clicked = (event) => { /* … */ }
  #beforeCache = () => { /* reset to the server's state */ }
}

customElements.get("unmagic-thing") || customElements.define("unmagic-thing", UnmagicThing)
```

- **The header comment is the element's documentation.**
  - The first line is `// <unmagic-thing …> — what it is, rendered by \`helper\`.`
  - Then the gaps it fills in the native markup, its attributes, and its
    events.
  - See `menu.js`, `tooltip.js` and `modal.js`.
- **Listeners on the element go in the constructor**, so they run once. A
  moved element never doubles them up (`tooltip.js`).
- **Listeners on `document` or `window` are added in `connectedCallback` or
  when opened, and always removed.** Remove them in `disconnectedCallback` or
  on close (`menu.js`).
- **Private state and handlers** use `#fields` and arrow-function properties.
- **Configuration comes from attributes Ruby renders.** Use
  `observedAttributes` when an attribute can change after connect
  (`tooltip.js`).
- **Events** are named `unmagic-<name>:<event>` and bubble
  (`unmagic-tabs:change`, `unmagic-clipboard:copy`).
- **Behaviour on plain elements, rather than on a wrapper,** is wired once by
  delegation from `document`, guarded with a `Symbol.for` flag
  (`dialog.js`).
- **Shared helpers that aren't elements** are modules in the same folder. The
  existing examples are `dialog.js`, a delegated behaviour, and `upsert.js`, a
  stream action. Put code two elements need in one of these, e.g. anchored
  placement shared by tooltip and popover, rather than copying it.
- **An element that specialises another** extends it rather than duplicating
  it. The parent file adds `export { UnmagicMenu }` beside its `define`, and
  the child imports it by pinned name. Each file still defines one element.
- **Sibling modules** are imported by their pinned name
  (`import "unmagic/components/dialog"` in `modal.js`). There are no npm
  dependencies.

### Surviving Turbo

- **`turbo:before-cache`**: close whatever is open and put the element back to
  the server's state, so a restored snapshot isn't stuck open (`menu.js`).
  Anything sensitive is reset before the snapshot is taken, e.g. a revealed
  password goes back to masked, so a cached page never holds it in the clear.
- **`connectedCallback` must be idempotent against clones.** A snapshot can
  contain the DOM this script generated without this instance's wiring. Remove
  generated nodes and rebuild them (`tooltip.js`).
- **`turbo:morph`** resets markup to the server's state, so re-apply any
  client-side choice. Remember it in `sessionStorage` only when the caller gave
  an `id:` (`tabs.js`).
- **Permanent elements** (`data-turbo-permanent`) are moved into a fresh
  element on each visit, so keep timers and state in a module-level `WeakMap`
  keyed by the node, not on the element (`toasts.js`).
- **Streamed-in content** must work without setup. Use a `MutationObserver` or
  delegation, never a one-off scan at load (`toasts.js`, `dialog.js`).

## Accessibility

- **Follow the WAI-ARIA Authoring Practices pattern** for the widget (menu,
  tabs, dialog, switch, disclosure, combobox, tree). The server renders roles
  and initial state, and script keeps state attributes true.
- **Keyboard parity with the pattern.**
  - Arrow keys, Home and End move within a composite. Escape closes. Tab leaves
    and closes a popup. See `menu.js` and `tabs.js`.
  - Composites use a roving `tabindex`, so only the active item is in the tab
    order.
- **Focus.**
  - Opening from the keyboard focuses the first item.
  - Closing with Escape returns focus to the trigger (`menu.js`).
  - A dialog relies on the native `<dialog>` focus handling.
- **Names.** An icon-only button has `aria-label` and a matching `title`
  (`menu.rb`, `copy_button.rb`), and decorative SVG is `aria-hidden`.
- **Announcements.**
  - A transient result is announced through a polite live region
    (`copy_button.rb`, "Copied").
  - An error summary is `role="alert"` (`form_builder.rb`).
  - A loading placeholder is hidden from screen readers and announces a single
    label instead (`skeleton.rb`).
- **Motion and colour.** Honour reduced motion, and never carry meaning by
  colour alone: a tone brings an icon or text as well (`callout.rb`).

## Forms

**Decided: the gem styles form controls.** This covers text inputs, textareas,
selects, checkboxes, radios, and the composite controls built on them (switch,
password reveal, one-time code, combobox). It replaces the earlier rule, where
`FormBuilder` emitted only structure. When the first control style lands,
update the class comment in `form_builder.rb` to match.

So that this styling can't clash with a host's own inputs:

- **Styles hang off classes, never bare element selectors.** Examples:
  `UnmagicInput`, `UnmagicSelect`, `UnmagicCheck`, `UnmagicRadio`,
  `UnmagicSwitch`. An `<input>` the gem didn't render is untouched.
- **The builder adds the class.** `field`, every builder method and the `_tag`
  helpers put the control class on what they build, so styling is on by default
  wherever the builder is used.
- **The class comes through a seam.** It is a callable on `Configuration`, like
  `submit_class`, called with the control kind:
  `config.control_class = ->(view, kind) { … }`. An app with its own input
  styles returns its own classes, or `nil` to opt out.
- **Each control passes its own kind to `control_class`.** A host can then
  treat a combobox differently from a plain input, but most hosts map
  everything text-like to one class. These are the kinds:

  | Kind | Controls | Default class |
  |---|---|---|
  | `:input` | text, email, number, url, search and the like | `UnmagicInput` |
  | `:text_area` | textarea | `UnmagicInput` |
  | `:password` | `password_field` | `UnmagicInput` |
  | `:one_time_code` | one-time code | `UnmagicInput` |
  | `:date` | date and time inputs | `UnmagicInput` |
  | `:combobox` | combobox control | `UnmagicInput` |
  | `:select` | `<select>` | `UnmagicSelect` |
  | `:check` | checkbox | `UnmagicCheck` |
  | `:radio` | radio | `UnmagicRadio` |
  | `:switch` | switch | `UnmagicSwitch` |

  A new control adds a row here rather than inventing a kind in its note.
- **A control outside the builder** gets the same class from
  `control_classes(kind)`, the form-control counterpart of `button_classes`. It
  is for a `select_tag` or a hand-written `<input>`.
- **State comes from attributes and pseudo-classes:** `:disabled`,
  `[aria-invalid="true"]`, `:checked`, `:indeterminate`, `:user-invalid`, and
  `:focus-visible` using the shared focus ring.
- **Native semantics are kept.** A styled checkbox or radio is still a real
  `<input>` (`appearance: none`, drawn with CSS), and a switch is a checkbox
  with `role="switch"`. Forms submit and reset natively.
- **Structure classes stay:** `UnmagicField`, `UnmagicLabel`, `UnmagicHint`,
  `UnmagicError`, `UnmagicCheckField`, `UnmagicCheckList`. An invalid control
  gets `aria-invalid`, and a required one gets `required`.

## Tests

- **One spec file per feature group** in `spec/unmagic/components/`. Name new
  groups for what they cover (`primitives_spec.rb`,
  `menu_tabs_clipboard_spec.rb`).
- **Build a real view and parse what it renders.**
  - `build_view` gives a full view context (params, query, Turbo-Frame header),
    and `html(markup)` gives a Nokogiri fragment.
  - For forms use `build_form`, and for a stray `<tr>` use `html_row`
    (`spec/spec_helper.rb`).
- **Assert on structure, not strings.**
  - Selectors, classes, ARIA and `data-*` attributes, ids that link parts
    together, the em dash for blank input.
  - Extra `class:` and attributes reaching the root element.
  - `ArgumentError` for every validated option (`primitives_spec.rb`).
- **Configuration is reset after every example.** A spec that changes a seam
  needs no cleanup.
- **There are no JavaScript tests.** Behaviour is verified by hand in the
  preview, so the design note lists what to check there.

## Preview

The preview is a Rails app in one file (`config.ru`), run with `bin/dev` on
http://localhost:5701.

- **Each helper gets a `<section><h2>helper_name</h2>…</section>`** on the page
  that fits:
  - `primitives`: static building blocks
  - `elements`: custom elements
  - `dialogs`: anything that opens over the page
  - `skeletons`: loading states
- **Show every variant and tone side by side.** Use realistic copy, not lorem
  ipsum (`primitives.html.erb`).
- **A new page** needs three things:
  - a route in `config.ru`
  - an action in `preview/preview_controller.rb`
  - a nav link in `preview/views/layouts/preview.html.erb`
- **Check light and dark** (`?theme=dark`), keyboard-only use, and reduced
  motion.

## Documentation

- A README section for the helper, under the matching heading. Copy the
  helper's comment, with its import line and I18n keys.
- New tokens go in the README's Theming list.
- A bullet in `CHANGELOG.md` for the next release.
- Update the gemspec `description` when the component is headline-worthy.

## Checklist for a new component

1. The design note `docs/components/<name>.md` is written and reviewed.
2. Ruby class, require, helper (or `FormBuilder` method) with its doc comment.
3. CSS section: tokens with fallbacks, attribute-driven state, focus, reduced
   motion.
4. Custom element with a header comment, Turbo-safe, registered in
   `components.js`, if the component needs script.
5. Spec covering structure, ARIA, passthrough options and `ArgumentError`.
6. Preview section, checked in light and dark, by keyboard, and with reduced
   motion.
7. README, CHANGELOG and, if needed, the Theming list.
8. `bundle exec rspec` and `bundle exec rubocop` pass.

## Open decisions

These need an answer before the components that depend on them are built.
Settled ones stay listed, struck through, so the reasoning isn't lost.

### Decided in the component design review

- **Shared placement, and `menu` on the Popover API.**
  - Anchored placement moves out of `tooltip.js` into a `position.js` module,
    which tooltip, popover, menu, context menu and combobox all use.
  - `menu` moves from `<details>` to a `popovertarget` button and a
    `popover="auto"` panel. That still opens with no JS, and the panel is no
    longer clipped by overflow containers.
  - This lands before popover, context menu and combobox. See
    [`components/position.md`](components/position.md).
- **Overriding Rails builder methods is allowed** when the new behaviour is
  opt-in and the default matches Rails, as `label` and `submit` already do.
  Example: `form.password_field :password, reveal: true`.
- **Combobox remote search requires Turbo** (a Turbo Frame), documented in its
  import line.
- **Emoji picker** ships curated emoji only; the gem bundles no emoji dataset.
- **New theme tokens accepted:** the avatar palette `--unmagic-avatar-1..6`
  and `--unmagic-rating`. The switch thumb reuses `--unmagic-raised`, and the
  lightbox reuses `--unmagic-backdrop`.
- **Smaller defaults:**
  - The bulk selection method is `table.selectable`.
  - A banner remembers its dismissal in localStorage, with optional
    `dismiss_url:`.
  - `check_box_collection` gains `legend:`, `hint_method:` and
    `variant: :cards`, to match radios.
  - The carousel has no autoplay.
  - Hotkeys ship without key sequences in v1, but with a page-level off switch.

### Still open

1. ~~How far form-control styling goes.~~ **Decided: the gem styles form
   controls.** See [Forms](#forms).
2. ~~Where marketing-style components belong.~~ **Decided: the core
   stylesheet.** Marquee, testimonial, dock and feedback get ordinary sections
   in `components.css` and follow the same rules as everything else. Rails
   Blocks doesn't separate them either.
3. **Pickers that duplicate native inputs** (date, colour, emoji). **Decided:
   build a custom picker only if it is clearly better than the native input.**
   Each picker's note must end with an explicit comparison against the native
   input (and, for emoji, against the operating system's own picker). The
   comparison covers:
   - what users gain
   - what accessibility, mobile behaviour and locale handling it costs
   - how much JS and data it ships

   The note then recommends one of three outcomes: replace the native input,
   enhance it, or skip the component. Where the gain is marginal, the default
   is to enhance or skip.
