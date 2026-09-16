# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `trailing` on the page header builder puts markup beside the title as it is —
  a status partial, a row of badges a helper already returned. `badge` wraps what
  it is given, so an already-rendered one routed through it came out as a badge
  inside a badge; this is the counterpart to `leading`, and the two interleave in
  call order.
- `sortable_list` and `sortable_handle`: drag-and-drop ordering by pointer or
  keyboard, extracted from hooops.
  - Elements `<unmagic-sortable-list>`, `<unmagic-sortable-item>` and
    `<unmagic-sortable-param>`.
  - Keyboard reordering with announcements.
  - Scrolling at the edges, Escape to cancel, and nested lists.
  - A cancelable `unmagic-sortable:move` event.
  - Touch: a long press lifts an item, so swipes still scroll and taps still
    tap; a grip drags at once.
  - `sortable-*` Tailwind variants.
  - `config.sortable_item` and `config.sortable_url`, which the new
    unmagic-sortable gem fills in.
- `board`, a Trello-style board of reorderable columns and cards, with add-card
  and add-list forms (`board.js`).

- AI chat components, for rendering an agent's work. Designed from three
  applications that each grew their own agent UI, and checked against
  assistant-ui's primitives. Each has a design note in `docs/components/ai_chat`
  and a page in the preview:
  - `ai_chat`, the transcript: a polite log that follows new content while the
    reader is at the bottom, with a jump-to-latest button and a welcome slot.
  - `ai_chat_message`: a user's bubble or an assistant's prose, with reasoning,
    actions, branches and attachments, and an optimistic template.
  - `ai_chat_tool_call`: a row per tool call, joined into a timeline, with a
    live clock, progress, partial-failure counts and folded payloads.
  - `ai_chat_payload`, `ai_chat_reasoning`, `ai_chat_failure`, `ai_chat_plan`
    and `ai_chat_workspace`.
  - `ai_chat_request`, `ai_chat_permission` and `ai_chat_proposal`, for an agent
    that stops to ask.
  - `ai_chat_composer` (with `ai_chat_composer_action` and
    `ai_chat_stop_form`), `ai_chat_slash_menu`, `ai_chat_welcome`,
    `ai_chat_attachments` and `ai_chat_dropzone`.
  - `ai_chat_citation`, `ai_chat_action_bar` and `ai_chat_branch_picker`.
- `streaming_markdown_tag` and `turbo_stream.stream_markdown`: server-rendered
  HTML revealed at a steady pace as fuller renders arrive
  (`<unmagic-streaming-markdown>`).
- `elapsed_tag`, a clock counting up from a time or down to one
  (`<unmagic-elapsed>`).
- `avatar` and `avatar_group`, with initials on a tint picked from the name.
- `UnmagicProse`, styles for server-rendered Markdown.
- `config.code_block`, the seam payloads and prose code blocks render through,
  for a host's highlighter.
- Custom elements `<unmagic-autoscroll>`, `<unmagic-optimistic>`,
  `<unmagic-toolbar>`, `<unmagic-slash-menu>` and `<unmagic-dropzone>`.
- The preview groups components under headings, with the AI chat components in
  their own group. Its composer example posts for real and streams a reply.

### Changed

- The gem now depends on `unmagic-icon` and `unmagic-color`. Its glyphs are
  Lucide SVGs shipped in `app/assets/icons/lucide` and rendered through
  unmagic-icon, in place of the inline paths. The rendered `<svg>` gains
  unmagic-icon's `unmagic-icon` class and `data-unmagic-icon` attribute, and the
  modal's retry icon is Lucide's `rotate-cw`.
- The `upsert` stream action's placement rule moved to
  `unmagic/components/placement`, shared with `<unmagic-optimistic>`. Its
  behaviour is unchanged.

### Fixed

- `duration="0"` on `<unmagic-toasts>` now keeps a toast up until it is
  dismissed, so "don't take this one away" is sayable — and a test asserting on a
  toast can stop racing the timer. It used to fall back to the default, because
  the guard was `duration > 0` and `Number(null)` is also `0`, so an absent
  attribute and a deliberate zero were indistinguishable. Absent, empty, negative
  and unparseable all still fall back rather than silently pinning every toast to
  the screen.

- The helpers reach `ActionView::TestCase` too, so a host helper that composes
  one of them (`badge`, `button_classes`) can be exercised by the host's own
  helper spec. The engine only ran the `:action_view` load hook, which mixes
  into `ActionView::Base` — what a template renders through, and not what a
  helper test calls its subject on. The symptom was a helper that worked in the
  app and raised `NoMethodError` in its spec, which is a confusing place to send
  someone.

## [0.3.0] - 2026-09-16

### Added

- Styled form controls:
  - `FormBuilder`'s text-like fields (`text_field`, `email_field`,
    `password_field`, `date_field`, `text_area` and the rest) wear
    `UnmagicInput`.
  - Its selects wear `UnmagicSelect`.
  - `check_box_field` and `check_box_collection` wear `UnmagicCheck`.
  - The classes come from the new `config.control_class` seam, called with
    `(view, kind)`.
- `control_classes(kind, size:)` gives a control outside the builder the same
  classes, for a `select_tag` or a hand-written radio. It takes `:small` and
  `:large` sizes that match `button_classes`.
- The preview app (`bin/dev`) is rebuilt as component docs: a sidebar, an
  overview of every component with a live thumbnail, and a page per component
  whose examples each show their source beside the rendered result.

### Changed

- **Breaking: the styles are Tailwind CSS v4, and your app needs Tailwind v4.**
  - The gem's styles are now a Tailwind source file,
    `app/assets/tailwind/unmagic_components/engine.css`, compiled by your app's
    own Tailwind build.
  - It uses Tailwind's palette with `dark:` variants, so dark mode follows your
    app's `dark` variant.
  - The rules sit in `@layer components`, so utilities passed as `class:`
    override them.
  - `unmagic/components.css` and every `--unmagic-*` theming variable are
    removed.
  - To migrate: drop `stylesheet_link_tag "unmagic/components"`, and add
    `@import "../builds/tailwind/unmagic_components";` after
    `@import "tailwindcss";` in `app/assets/tailwind/application.css`. Then move
    any `--unmagic-*` overrides into your `@theme` colours or your `dark`
    variant.
- **Form controls now carry a class, and the gem's CSS styles them.** An app
  that styles its inputs itself keeps its own look with
  `config.control_class = ->(_view, _kind) { nil }`, or points the seam at its
  own classes.

## [0.2.0] - 2026-09-16

### Added

- Dialogs, each a native `<dialog>` sharing one panel (a titled header with a
  close button, the body, and an optional footer):
  - **The shared modal.** Mount it with `modal_frame`, point links at it with
    `modal_link_to`, and render a `dialog` from the action. `form:` builds the
    form around the whole panel. The `<unmagic-modal>` element opens on the
    frame's request with a skeleton, and shows an error panel with a retry when
    the load fails. It closes in the same render as a `turbo_stream.refresh`, so
    the page repaints once. `Unmagic::Components::DialogResponder` provides the
    `refresh_or_redirect` that sends that refresh, and `config.modal_frame_id`
    renames the frame.
  - **Dialogs already on the page:** `dialog_tag` and `dialog_button`.
  - **A confirm dialog in place of `window.confirm`** for `data-turbo-confirm`
    (`import "unmagic/components/confirm"`). `data-turbo-confirm-title`,
    `-accept` and `-variant="danger"` customise it, and `confirm_dialog_template`
    carries its words through I18n.
- Page building blocks with no JavaScript:
  - `page_header` shows a back link, a title with badges, a description and
    actions.
  - `card` has a header with actions and a tinted footer. `flush:` suits a table
    that runs edge to edge, and `href:` makes the whole card one link.
  - `badge` comes in neutral, good, warn, bad, info and accent tones.
  - `callout` comes in neutral, good, warn, bad and info tones, each with an icon
    and an optional title and badge.
  - `empty_state` is now a helper you can call directly, still rendered through
    the `empty_state` setting. A new `--unmagic-surface-3` token colours neutral
    badges.
- `local_time_tag` and `<unmagic-time>`. A timestamp the browser formats with
  `Intl`, in the viewer's locale and time zone. The formats are short, medium,
  long, full, date, time and relative. Relative times keep themselves current on
  one shared, minute-aligned timer, and `compact: true` shortens them to "5m".
- `tooltip` and `<unmagic-tooltip>`. A hint on hover or focus, drawn in the top
  layer so nothing clips it. It flips to the other side when there isn't room,
  stays on screen, and closes on Escape. Plain text is styled as a term. New
  `--unmagic-tooltip` and `--unmagic-on-tooltip` tokens colour it.
- `menu` and `<unmagic-menu>`. A dropdown built on `<details>` with `link`,
  `button` and `divider` items. It closes on an outside click, Escape, choosing an
  item, or a Turbo navigation, and supports keyboard navigation.
- `tabs` and `<unmagic-tabs>`. Panels switched in the page using the ARIA tab
  pattern with arrow-key navigation, including disabled tabs that show a reason.
  With an `id:` the choice is remembered. With `href:`, tabs become a link bar
  rendered on the server. A new `--unmagic-raised` token colours the selected tab.
- `copy_button` and `<unmagic-clipboard>`. Copies text, or the contents of an
  element given by `from:`, then briefly shows a check and announces it. It fires
  `unmagic-clipboard:copy` and `unmagic-clipboard:error`.
- `FormBuilder#autogrow_text_area` and `autogrow_text_area_tag`. A textarea that
  grows from its rows to its CSS max-height, re-measuring as you type, on reset
  and when its width changes.
- `FormBuilder#uuid_field` and `uuid_input_tag`. A hidden field holding a UUIDv7,
  generated on the server and again in the browser when the page loads and each
  time the form resets.
- Skeletons for blocking out an interface while it loads. `skeleton do |s|` yields
  `s.text`, `s.circle`, `s.block` and `s.button`, arranged with your own markup
  and announced once as "Loading…". `skeleton_text`, `skeleton_circle`,
  `skeleton_block` and `skeleton_button` are the same shapes outside a block.
  Shapes take their size from what they replace: a text line fills one line of
  its font, and a button shape is a real button's height. `detail_list`,
  `page_header` and `card` take `skeleton: true` to render a skeleton version of
  themselves.
- Toasts. `flash_toasts` turns the request's flashes into toasts that dismiss
  themselves, pause while hovered or focused, and survive Drive visits and morph
  refreshes. `turbo_stream.toast` shows one from a stream response.
  `config.flash_tones` maps flash types to the good, warn, bad and info tones,
  which take their colours from the new `--unmagic-good*` and `--unmagic-warn*`
  tokens.
- `button_classes`, with `:primary`, `:ghost`, `:danger` and `:icon` variants and
  `:small` and `:large` sizes.
- `import "unmagic/components"` imports every component. The engine pins each one
  as `unmagic/components/<name>`.
- `--unmagic-focus` and `--unmagic-backdrop` theme tokens.
- `table_for` passes any option it doesn't recognise to the `<table>` element, so a
  view can set `class:`, `data:` or ARIA attributes without a wrapper. `id:` still
  names the deferred turbo frame.
- `table.empty` and `table.no_results` take extra options and hand them to the
  configured `empty_state` seam, for an app whose blank slate needs more than a
  message (an icon, say).
- Live tables. `columns:` moves a table's column definitions into a partial, and
  `row_for` renders the single `<tr>` those columns produce for one record, so a
  Turbo Stream broadcast and the page render cannot drift. `rows_id:` puts an id
  on the `<tbody>` for a stream to target, and `row_id:` overrides the row's own
  id — needed over an STI collection, where `dom_id` names each subclass and the
  rows would sort by type rather than by id.
- `FormBuilder`, the chrome around a form control: the `field` wrapper with its
  label, required marker, hint and error line; `group` for a row of fields;
  `errors_summary`; `check_box_field` and `check_box_collection`; `form_value_for`;
  and a `submit` that conjugates its own label while submitting ("Save" ->
  "Saving…") through `data-turbo-submits-with`. It deliberately does not style the
  control itself — apps disagree about whether inputs carry a class or are styled
  bare — so it emits structure and leaves appearance to the host.
- The `upsert` Turbo Stream action (`import "unmagic/components/upsert"`), which
  merges `append` and `replace`: a row already on the page is replaced in place,
  and a new one is inserted at the position its id sorts to. `order="desc"` on the
  stream tag flips that for a newest-first list.

## [0.1.0] - 2026-09-10

### Added

- `table_for`, a declarative index-table builder: columns with blocks or attribute
  names, sortable headers with `aria-sort`, right/centre alignment, numeric columns,
  `<colgroup>` width pinning, companion detail rows, and two flavours of empty state.
- Deferred tables — `table_for collection, defer: true` renders a skeleton inside a
  Turbo Frame without touching the collection, then loads the real rows into it.
- `table_tag`, the underlying primitive, for static tables built from plain arrays.
- `detail_list`, a description-list builder with inline and stacked variants.
- Theming through `--unmagic-*` CSS custom properties, with every value falling back
  to a Tailwind palette default so the components look right unconfigured.
- Configurable empty-state, pagination and Pagy seams so the gem depends on neither
  Pagy nor any host helper.

[Unreleased]: https://github.com/unreasonable-magic/unmagic-components/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/unreasonable-magic/unmagic-components/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/unreasonable-magic/unmagic-components/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/unreasonable-magic/unmagic-components/releases/tag/v0.1.0
