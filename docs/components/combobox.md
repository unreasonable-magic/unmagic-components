# `combobox`

> Status: built
> Tier: 3 (large)
> Replaces or relates to: the gap source is Rails Blocks "Combobox (multi-select)" and "Autocomplete Search". Builds on `form_builder.rb` (`form_value_for`, `field`), the shared placement in `position.js` and `menu` on the Popover API ([position.md](position.md), built first), the keyboard handling in `menu.js`, Turbo Frame loading and errors in `modal.js`, the `empty_state` seam and `Skeleton`. `command_palette` is built on it.

## Purpose

This picks one or many records from a list too long for a `<select>` or a
column of checkboxes. The user types to narrow the list, then chooses. Typical
uses are an assignee, labels on an issue, or a country. The list is either
rendered with the page (static) or searched on the server as the user types
(remote). The server renders the options in both cases, so the browser does no
templating.

It is **not**:
- a menu of actions (use `menu`)
- a short fixed choice (use a native `<select>` or `radio_button_collection`)
- free text with suggestions only (use `<input list>` with a `<datalist>`)

## Phases

Each phase ships on its own and leaves the API compatible with the next.

1. **Static, single.** Options rendered inline and filtered in the browser.
   `FormBuilder#combobox` and `combobox_tag`.
2. **Multiple.** Chips, Backspace to remove, form `reset`, `required`.
3. **Remote.** `src:` searches through a Turbo Frame, with
   `combobox_results` for the endpoint, plus loading, empty and error rows.
4. **Create.** An option to add the typed text as a new value.

## API

```erb
<%# Phase 1: static, single, inside a field %>
<%= form.field :owner_id, "Owner", as: :combobox,
      collection: @team.members, text: :name, placeholder: "Pick someone" %>

<%# Phase 2: multiple %>
<%= form.combobox :label_ids, collection: Label.order(:name), text: :name, multiple: true %>

<%# Rich options from a block; label: is what the input and chip show %>
<%= form.combobox :owner_id, collection: @team.members do |combobox, member| %>
  <% combobox.option member.id, label: member.name, keywords: member.email do %>
    <%= avatar member %> <%= member.name %> <span class="text-muted"><%= member.email %></span>
  <% end %>
<% end %>

<%# Phase 3: remote. collection: is only what is already selected %>
<%= form.combobox :owner_id, collection: [ @task.owner ].compact, text: :name,
      src: search_members_path, min_length: 1 %>

<%# Phase 4: create %>
<%= form.combobox :label_ids, collection: @issue.labels, text: :name, multiple: true,
      src: search_labels_path, create: "issue[new_label_names][]" %>

<%# Outside a form builder %>
<%= combobox_tag "owner_id", collection: @team.members, text: :name, selected: params[:owner_id] %>
```

The endpoint for `src:` is an ordinary action. It receives `?q=` and renders
the results:

```erb
<%# members/search.html.erb %>
<%= combobox_results @members, text: :name %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `collection:` | enumerable | `[]` | The options (static), or the selected records (remote) |
| `value:` | method name or lambda | `:id` | Called on each record |
| `text:` | method name or lambda | `:to_s` | Label for the option, input and chip |
| `multiple:` | boolean | `false` | Submits `name[]` |
| `src:` | URL | `nil` | Remote search; needs Turbo |
| `min_length:` | integer | `1` | Characters before a remote search; `0` loads on open |
| `debounce:` | ms | `200` | Remote only |
| `placeholder:` | string | `nil` | On the text input |
| `create:` | param name, or `false` | `false` | Where created texts are submitted (phase 4) |
| `selected:` | value or array | `form_value_for` | `combobox_tag` only; the builder reads the object |

- **Builder:** the block is called once per record with
  `(combobox, record)`. `combobox.option(value, label:, keywords: nil, disabled: false, &block)`
  records one option, and `combobox.group(label) { … }` wraps options under a
  heading. Without a block, options come from `value:` and `text:`.
- **Options passthrough:**
  - `required:`, `aria-invalid` and `id` (from `field`) go on the visible text
    input, so `field`'s `<label for>` points at it.
  - `class:` and other options go on `<unmagic-combobox>`.
- **Empty collection:**
  - Static: renders the input, and the list shows the empty row.
  - Remote: normal.
- **`combobox_results(records, value:, text:, &block)`:**
  - Takes the same builder block.
  - On a frame request it wraps itself in `turbo_frame_tag(turbo_frame_request_id)`,
    as `dialog` does with the modal frame, and derives option ids from that
    frame id.
  - An empty collection renders the empty row through the `empty_state` seam.

## Markup

Static, multiple, one label chosen, before any script runs:

```html
<unmagic-combobox class="UnmagicCombobox" id="issue_label_ids_combobox" multiple>
  <div class="UnmagicCombobox__control">
    <ul class="UnmagicCombobox__chips" aria-label="Selected">
      <li class="UnmagicCombobox__chip" data-value="3">
        <span class="UnmagicCombobox__chip-label">Bug</span>
        <button type="button" class="UnmagicCombobox__remove" aria-label="Remove Bug">
          <svg class="UnmagicIcon" aria-hidden="true">…x…</svg>
        </button>
        <input type="hidden" name="issue[label_ids][]" value="3">
      </li>
    </ul>
    <input type="text" id="issue_label_ids" class="UnmagicCombobox__input"
           role="combobox" aria-expanded="false" aria-autocomplete="list"
           aria-controls="issue_label_ids_combobox_listbox" autocomplete="off" spellcheck="false">
  </div>
  <input type="hidden" name="issue[label_ids][]" value="" data-unmagic-combobox-blank>
  <div class="UnmagicCombobox__popup" popover="manual">
    <div role="listbox" id="issue_label_ids_combobox_listbox" class="UnmagicCombobox__listbox"
         aria-multiselectable="true" aria-label="Labels">
      <div role="option" id="issue_label_ids_combobox_option_3" class="UnmagicCombobox__option"
           data-value="3" data-label="Bug" aria-selected="true">Bug</div>
      <div role="option" id="issue_label_ids_combobox_option_4" class="UnmagicCombobox__option"
           data-value="4" data-label="Chore" aria-selected="false">Chore</div>
    </div>
    <p class="UnmagicCombobox__status UnmagicVisuallyHidden" role="status"></p>
  </div>
</unmagic-combobox>
```

- **Single mode:**
  - There are no chips.
  - One `<input type="hidden" name="task[owner_id]">` holds the value.
  - The text input shows the selected label as its `value`.
- **Blank hidden input:** as with `collection_check_boxes`, an empty
  `name[]` means removing every chip still submits an empty array.
- **Remote:** the listbox holds a `<turbo-frame id="…_results">` that the
  element points at `src?q=…`.
- **Why no `<select>`:** the hidden inputs are the source of truth. A form
  submitted before the script loads keeps the current value, which meets
  principle 1 ("readable before script"). A `<select>`-backed version was
  considered and rejected (see Open questions): a remote list can't be a
  `<select>`, and one markup shape for all phases keeps the element simple.
- **Popup:** a manual popover in the top layer, placed by `position.js`, so
  a card's or table's `overflow` can't clip it. Inside a modal `<dialog>` it
  is still in the dialog's subtree, so it is not made inert.

## Accessibility

- **Pattern:** WAI-ARIA APG
  [combobox with listbox popup](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/),
  using `aria-activedescendant`, so DOM focus never leaves the input.
- **Server renders:**
  - `role="combobox"`, `aria-controls`, `aria-autocomplete="list"`,
    `aria-expanded="false"`
  - `role="listbox"`, with `aria-multiselectable` for multiple
  - each option's `aria-selected`
  - `aria-disabled` on disabled options
- **Script keeps true:** `aria-expanded`, `aria-activedescendant`,
  `aria-selected`, `aria-busy` on the listbox while loading, and the status
  text.

| Key | In the input |
|---|---|
| Down | Opens the list; if already open, moves the active option down (wraps) |
| Alt+Down | Opens without moving the active option |
| Up | Moves the active option up (wraps); opens at the last option |
| Enter | Chooses the active option. Single: fills the input and closes. Multiple: toggles it and stays open. With no active option, does nothing and lets the form submit |
| Escape | Closes the list. If already closed: clears the query (multiple) or restores the selected label (single) |
| Tab | Closes and moves on. Never selects |
| Backspace | Multiple, on an empty input: removes the last chip |
| Home / End | Move the caret (the native text behaviour, per APG) |

- **Chips:** each remove button is a real button in the tab order, named
  "Remove Bug". After a removal, focus goes back to the input.
- **Announcements:** the polite status reads the result count after each
  filter or load ("5 results", "No matches") and "Searching…" while a remote
  load runs.
- **Colour:** the chosen option carries a check icon, not just a tint.
- **Disabled options:** skipped by arrow keys, and not choosable.

## Styling

Section `/* Comboboxes */`.

- **Elements:**
  - `UnmagicCombobox`, `__control`, `__chips`, `__chip`, `__chip-label`,
    `__remove`, `__input`
  - `__popup`, `__listbox`, `__group`, `__group-label`, `__option`,
    `__check`, `__status`
  - `__message` (the loading, empty and error rows), `__create`
- **State from attributes:**
  - `.UnmagicCombobox__option[data-active]`: the highlighted option. The
    element sets `data-active` alongside `aria-activedescendant`, since CSS
    can't select the referenced node.
  - `[aria-selected="true"]` shows `__check`.
  - `[aria-disabled="true"]` is dimmed.
  - `[aria-busy="true"]` on the listbox.
  - `[hidden]` on filtered-out options and groups.
- **The control** is styled by the gem, following the principles' Forms
  section:
  - `__control` also gets `config.control_class.call(view, :combobox)`
    (`UnmagicInput` by default), so it has the same border, radius, height,
    `[aria-invalid]` and `:focus-within` ring as every other gem input.
  - The inner `<input>` is reset to borderless and transparent inside it.
  - A host that returns `nil` from the seam gets an unstyled control. The
    chips and listbox are still styled, because they are the component, not a
    control.
- **Colours** (palette with `dark:` variants, nothing new):
  - `white`/`dark:neutral-900` and `neutral-200`/`dark:neutral-800` for the
    control and popup
  - `neutral-100`/`dark:neutral-800` for chips and the active option
  - `neutral-500` for placeholders and group labels
  - the `neutral-400`/`dark:neutral-500` focus ring, and `red-600`/`dark:red-400`
    with `aria-invalid`
- **Popup:** the menu panel's radius (0.5rem) and shadow, and
  `max-height: 18rem` with scrolling. The active option is scrolled into view
  with `block: "nearest"`.
- **Motion:** none. The popup appears and disappears without transitions.

## Small screens

Options are 44px tall on a coarse pointer and chip removers grow to 28px; the list is a popover capped at 18rem, so the keyboard doesn't push it off screen.

## Behaviour (JavaScript)

`app/assets/javascripts/unmagic/components/combobox.js` defines
`<unmagic-combobox>`.

- **Attributes:**
  - `multiple`
  - `src`, `min-length`, `debounce`
  - `create` (the param name)
  - `mode="value"` (default) or `mode="activate"`, used by `command_palette`
- **Static filter:** matches on `data-label` + `data-keywords`, normalised
  with `toLocaleLowerCase()` and NFD diacritic stripping. Non-matches get
  `hidden`, as does a group left with none. The first visible option becomes
  active.
- **Choosing:**
  - Single: writes the hidden input and the input's text.
  - Multiple: clones a chip from a `<template data-unmagic-combobox-chip>` that
    Ruby renders (so the chip markup and I18n stay server-side), and adds or
    removes it with its hidden input.
  - Both dispatch `input` and `change` on the hidden input, so other scripts
    see it.
- **Remote:**
  - Debounces input, then sets the frame's `src` to `src?q=`. Turbo aborts the
    stale request itself.
  - While fetching: `aria-busy`, and the loading row (a `<template>` holding
    `skeleton_text` lines, following `modal.js`'s `#fill`).
  - `turbo:frame-load`: marks `aria-selected` for chosen values, sets the first
    option active, and announces the count.
  - Errors reuse `modal.js`'s three cases (`turbo:fetch-request-error`,
    `turbo:frame-missing`, and an empty error response) and fill the error row,
    whose "Try again" reloads the frame.
- **Create (phase 4):**
  - When the query has no exact label match, a `__create` option
    "Create “foo”" is shown last.
  - Choosing it adds a chip whose hidden input is named by `create` with the
    text as its value, so ids and new names never share a param.
- **Placement:** on open, `showPopover()`, set the popup's width to the
  control's, then call `anchor(popup, control, { side: "bottom", align: "start" })`
  from `unmagic/components/position` (see [position.md](position.md)).
  - It flips above when there's no room below.
  - It re-places on scroll, resize, and when the results frame changes the
    popup's height.
  - `release()` runs on close.
- **Closing:** the popup closes on outside `pointerdown`, on Escape, and on
  Tab. Listeners live on the document only while it is open (`menu.js`).
- **Form:** on the form's `reset` event, the element restores the selection it
  captured at connect (`autogrow.js`, `uuid_input.js`). A `required` combobox
  with nothing chosen sets `setCustomValidity` on the text input, so native
  validation blocks the submit.
- **Events:** `unmagic-combobox:change`, with `detail: { values }`.
- **Turbo:**
  - `turbo:before-cache`: close the popup, clear the query and the remote
    results, and restore the selection captured at connect. A snapshot then
    shows the server's state, as native inputs do.
  - `turbo:morph`: the morph resets the chips and hidden inputs to the
    server's selection. If the user has a dirty, unsubmitted selection, the
    element keeps it in a private field and re-applies it after the morph
    (like `tabs.js` re-applies its selection). A clean one follows the server.
  - Snapshot clones: `connectedCallback` removes nodes the script generated
    (the loaded results, the status text, the create option) and rebuilds
    them. It treats the chips and hidden inputs it finds as the current
    selection, because those are the server's shape.
  - Streamed in: works on connect, with no document scan, and the results frame
    is its own child.
- **Dependencies:**
  - Static mode needs no Turbo.
  - `src:` needs Turbo. This is **decided**: remote search goes through a
    Turbo Frame, and the helper documents the requirement.
  - Sibling module: `unmagic/components/position`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.combobox.selected` | "Selected" |
| `unmagic.components.combobox.remove` | "Remove %{label}" |
| `unmagic.components.combobox.results` | one: "1 result", other: "%{count} results" |
| `unmagic.components.combobox.no_results` | "No matches" |
| `unmagic.components.combobox.loading` | "Searching…" |
| `unmagic.components.combobox.error` | "Couldn’t search" |
| `unmagic.components.combobox.retry` | "Try again" |
| `unmagic.components.combobox.create` | "Create “%{query}”" |

The results count is pluralised in the browser from two strings Ruby renders
into data attributes (`Intl.PluralRules` picks between them).

## Specs

`spec/unmagic/components/combobox_spec.rb`:

- **Static single, built by `build_form`:**
  - the input has `role=combobox`, the label `for` matches its id, and
    `aria-controls` matches the listbox id
  - the hidden input's name and value come from `form_value_for`
  - the input's value is the selected label
- **Multiple:**
  - a chip, remove button and `name[]` hidden input per selected value
  - the blank `name[]` input
  - `aria-multiselectable`
- **Builder options:** `label:`, `keywords:`, `disabled:` (`aria-disabled`),
  and groups with labels.
- **`as: :combobox` inside `field`:** `required` and `aria-invalid` land on
  the text input.
- **`combobox_tag`** with `selected:`.
- **Remote:** a `src:` frame with id `…_results` and no inline options;
  `min-length` and `debounce` attributes.
- **`combobox_results`:**
  - with `build_view(turbo_frame: "x_results")`: wrapped in that frame, with
    option ids prefixed from it
  - an empty collection renders through the `empty_state` seam (configured in
    the spec)
- **Create:** the `create` attribute and the chip template.
- **Passthrough:** `class:` and other attributes reach `<unmagic-combobox>`.
- **Control class seam:**
  - `__control` carries `UnmagicInput` by default.
  - A configured `control_class` returning `"form-input"` replaces it.
  - Returning `nil` leaves only `UnmagicCombobox__control`.
- **`ArgumentError`:**
  - `create:` given without `multiple:` in phase 4 (single create is deferred)
  - `min_length:` below 0

## Preview

A new **Forms** page (route, action and nav link), or the `elements` page
until one exists. It shows:
- a static single-select of 40 people with avatars
- a static multiple-select of labels in groups
- a remote search against `preview#search_people`, which sleeps 400ms so the
  loading row is visible, and returns an error for `q=boom`
- a create-enabled labels field
- all of these inside a `dialog_tag`, to check top-layer behaviour inside a
  modal

Check by hand:
- A full keyboard walkthrough following the table above, in VoiceOver:
  active option announced, count announced, chips named.
- The popup inside a `card` with `overflow: hidden` and inside a dialog; it
  flips near the viewport bottom.
- Submitting shows the right params (log them on the page), including an empty
  array after removing every chip.
- Form reset restores the selection.
- A Turbo visit away and back shows no stale open popup; a `turbo_stream.refresh`
  morph keeps a dirty selection.
- Dark theme, and reduced motion (nothing animates anyway).

## Open questions

1. ~~Control kind.~~ **Decided:** it's `:combobox`, per the kinds table in
   the principles' Forms section. A host that maps every text-like kind to one
   class still gets comboboxes styled for free.
2. **Created values:** is a separate param for created texts (`create:`
   naming it) the right shape, or should creating post to the server
   immediately and return an option?
3. **Morph:** re-applying a dirty selection may surprise when the server
   really did change the record. The alternatives are to always follow the
   server, or to let the host mark the field `data-turbo-permanent`.
4. **Limits:** is a `max:` selection count wanted in phase 2?
