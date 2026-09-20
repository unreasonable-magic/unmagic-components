# `command_palette`

> Status: built
> Tier: 3 (large)
> Replaces or relates to: the gap source is Rails Blocks "Command Palette". Built on `combobox` (its `mode="activate"` and remote results) inside a native `<dialog>` wired by `dialog.js`. Related notes: `hotkey.md` (opening shortcut) and `kbd.md` (shortcut hints). Depends on [position.md](position.md) through `combobox`, so it is built after `position.js`, the `menu` migration and `combobox`. The palette's own listbox is inline in the dialog, so it isn't placed by `position.js`.

## Purpose

A keyboard-first way to jump anywhere or run an action. The user presses ⌘K
(Ctrl+K elsewhere), types, and presses Enter. Commands are navigation (go to a
page or a record) or actions (sign out, create an issue). The server supplies
them: some rendered with the layout, and optionally more searched as the user
types (records).

It is **not** a replacement for visible navigation. Every command must also be
reachable another way. It is not for choosing a form value (use `combobox`).

## API

Render it once, in the layout, as `modal_frame` is:

```erb
<%= command_palette src: search_commands_path, placeholder: "Search or jump to…" do |palette| %>
  <% palette.group "Go to" do |group| %>
    <% group.link "Dashboard", root_path, keywords: "home", shortcut: %w[G D] %>
    <% group.link "Issues", issues_path %>
  <% end %>
  <% palette.group "Actions" do |group| %>
    <% group.link "New issue", new_issue_path, data: { turbo_frame: "modal" } %>
    <% group.button "Sign out", session_path, method: :delete,
         form: { data: { turbo_confirm: "Sign out?" } } %>
  <% end %>
<% end %>

<%# Anywhere: a visible trigger, which is required for discoverability %>
<%= command_palette_button class: button_classes(:ghost) %>
```

The endpoint for `src:` renders remote results as their own group:

```erb
<%= command_palette_results do |results| %>
  <% results.group "Issues" do |group| %>
    <% @issues.each { |issue| group.link issue.title, issue_path(issue), hint: "##{issue.number}" } %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | string | `"command_palette"` | The `<dialog>` id; `command_palette_button` targets it |
| `hotkey:` | hotkey string, or `false` | `"mod+k"` | `mod` is ⌘ on Apple platforms and Ctrl elsewhere |
| `src:` | URL | `nil` | Remote commands; needs Turbo |
| `min_length:` | integer | `2` | Before a remote search |
| `placeholder:` | string | I18n default | |

- **`group(label) { |group| }`** holds commands:
  - `group.link(name, url, keywords:, hint:, shortcut:, **link_options)`
  - `group.button(name, url, **button_to_options)`
  - Link and button options are link_to's and button_to's, so
    `data: { turbo_frame: "modal" }` and `turbo_confirm` just work.
- **`shortcut:`** renders `kbd` hints. It is display only; binding the keys is
  `hotkey.md`'s job.
- **Other options** go on `<unmagic-command-palette>`.
- **No groups and no `src:`** raises `ArgumentError`: a palette with nothing
  in it.

## Markup

```html
<unmagic-command-palette class="UnmagicCommandPalette" hotkey="mod+k">
  <dialog id="command_palette" class="UnmagicDialogBox UnmagicCommandPalette__dialog"
          data-unmagic-dialog aria-label="Command palette">
    <unmagic-combobox class="UnmagicCombobox UnmagicCombobox--inline" mode="activate"
                      id="command_palette_combobox" src="/commands/search" min-length="2">
      <div class="UnmagicCommandPalette__search">
        <svg class="UnmagicIcon" aria-hidden="true">…search…</svg>
        <input type="text" class="UnmagicCombobox__input" role="combobox" aria-expanded="true"
               aria-controls="command_palette_combobox_listbox" aria-autocomplete="list"
               autocomplete="off" autofocus placeholder="Search or jump to…">
      </div>
      <div role="listbox" id="command_palette_combobox_listbox" class="UnmagicCombobox__listbox"
           aria-label="Commands">
        <div role="group" class="UnmagicCombobox__group" aria-labelledby="command_palette_group_0">
          <div class="UnmagicCombobox__group-label" id="command_palette_group_0">Go to</div>
          <div role="option" id="command_palette_combobox_option_0" class="UnmagicCombobox__option"
               data-label="Dashboard" data-keywords="home" data-command="link">
            <a href="/" class="UnmagicCommandPalette__target" tabindex="-1">Dashboard</a>
            <span class="UnmagicCommandPalette__shortcut"><kbd class="UnmagicKbd">G</kbd><kbd class="UnmagicKbd">D</kbd></span>
          </div>
          <div role="option" … data-command="button">
            <form class="UnmagicCommandPalette__form" method="post" action="/session" data-turbo-confirm="Sign out?">
              …button_to's form, the button tabindex="-1"…
            </form>
          </div>
        </div>
        <turbo-frame id="command_palette_combobox_results"></turbo-frame>
      </div>
      <p class="UnmagicCombobox__status UnmagicVisuallyHidden" role="status"></p>
    </unmagic-combobox>
  </dialog>
</unmagic-command-palette>
```

- **The listbox is inline**, always shown inside the dialog rather than in a
  popover (`UnmagicCombobox--inline`).
- **Each option holds a real link or `button_to` form**, taken out of the tab
  order with `tabindex="-1"`. Activating the option clicks that inner target,
  so Turbo, `data-turbo-frame` and `turbo_confirm` behave exactly as they do
  for a normal link or button. No separate command runner is needed.
- **Without script** the dialog never opens, so the palette is invisible. That
  is acceptable because every command must be reachable elsewhere (Purpose).

## Accessibility

- **Pattern:**
  - an APG modal dialog, provided natively by `<dialog>.showModal()`
  - containing an APG combobox with an always-expanded listbox
    (`aria-expanded="true"`), using `aria-activedescendant`
- **Groups** are `role="group"` labelled by their heading. A group with no
  visible options is `hidden`.
- **Trigger button:**
  - `command_palette_button` is a `dialog_button`: `aria-haspopup="dialog"`
    and `aria-controls`
  - its label defaults to "Search" plus a `kbd` hint for the shortcut

| Key | Does |
|---|---|
| ⌘K / Ctrl+K | Opens the palette; when open, closes it |
| Down / Up | Moves the active command (wraps, skips group labels) |
| Home / End | Move the caret in the input |
| Enter | Activates the active command (clicks its link or submits its form) and closes |
| ⌘Enter / Ctrl+Enter | Opens a link command in a new tab (see Open questions) |
| Escape | Clears a non-empty query; on an empty query, closes the dialog (native) |
| Tab | Focus stays in the dialog (native modal focus containment) |

- **Focus:**
  - Opening focuses the input (`autofocus` inside a modal dialog).
  - Closing returns focus to whatever had it, which is native `<dialog>`
    behaviour.
- **Announcements:** as for combobox (the result count, "Searching…"), plus
  "No commands" when empty.
- **The hotkey** is ignored while focus is in an editable field unless it
  includes `mod`, so typing "k" in a textarea never opens it.

## Styling

Section `/* Command palette */`. It reuses `UnmagicDialogBox` for the backdrop
and entry animation, and every `UnmagicCombobox__*` option style.

- **Elements:**
  - `UnmagicCommandPalette__dialog`: top-aligned at 15vh,
    `width: min(40rem, 100vw - 2rem)`
  - `__search`: a large input row with a bottom border; the input is 1rem,
    borderless
  - `__shortcut`: right-aligned `kbd` hints, `neutral-500`
  - `__target` and `__form`: the target fills the option, with `display: contents`
    for the form, as `UnmagicMenu__form` has
- **Modifier:** `UnmagicCombobox--inline` makes the listbox static,
  `max-height: 60vh`, with no popup shadow.
- **Colour:** palette with `dark:` variants only, nothing new.
- **Motion:** the dialog's existing entry transition, off under reduced motion.

## Small screens

Below 40rem the dialog fills the screen, the list takes the rest of the height, and the shortcut hint on the button hides.

## Behaviour (JavaScript)

`command_palette.js` defines `<unmagic-command-palette>`, importing
`unmagic/components/dialog` and `unmagic/components/combobox`.

- **Hotkey:**
  - `connectedCallback` adds a `keydown` listener on `document` for the
    `hotkey` attribute, and `disconnectedCallback` removes it. It uses
    `hotkey.md`'s shared parser if that note settles on a module; otherwise it
    handles `mod+<key>` itself.
  - On match it calls `preventDefault` and toggles `dialog.showModal()` or
    `close()`.
- **Activation:**
  - `<unmagic-combobox mode="activate">` fires
    `unmagic-combobox:activate`, with `detail: { option, newTab }`.
  - The palette closes the dialog, then clicks `option.querySelector(".UnmagicCommandPalette__target")`,
    or calls `form.requestSubmit()`. Closing first means a `turbo_confirm`
    dialog or a modal link opens over the page, not over the palette.
- **On close:** the query is cleared, remote results are removed, and every
  option is un-hidden, so the next opening starts fresh.
- **Events:**
  - `unmagic-command-palette:open`
  - `unmagic-command-palette:close`
  - `unmagic-command-palette:run`, with `detail: { label }`
- **Turbo:**
  - `turbo:before-cache`: close the dialog and reset, so a snapshot never
    shows it open.
  - `turbo:morph`: the layout's palette is morphed to the server's commands.
    The open state is lost only if the morph replaces the dialog, so if it was
    open, the palette re-opens and restores the query.
  - Snapshot clones: remove generated results and status text on connect.
  - Streamed in: works on connect; there is no global setup beyond
    `dialog.js`'s delegation.
  - Not `data-turbo-permanent`: the commands can differ per page (for example
    contextual actions), so the fresh render wins.
- **Dependencies:** `dialog.js` and `combobox.js`. Turbo only for `src:`.
  Without Turbo, link activation still works through the native click.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.command_palette.label` | "Command palette" |
| `unmagic.components.command_palette.placeholder` | "Search or jump to…" |
| `unmagic.components.command_palette.button` | "Search" |
| `unmagic.components.command_palette.no_results` | "No commands" |

Counts, loading and errors reuse the `combobox` keys.

## Specs

`spec/unmagic/components/command_palette_spec.rb`:

- **Structure:**
  - a `<dialog>` with the id, `data-unmagic-dialog` and `aria-label`, holding
    an `<unmagic-combobox mode="activate">` with an inline listbox
  - `hotkey` attribute, defaulting to `mod+k`; `hotkey: false` omits it
- **Groups:** `role=group`, labelled by an id-linked heading.
- **Commands:**
  - `link` renders an option holding an `<a tabindex=-1>` with the link_to
    options (a `data-turbo-frame` passes through)
  - `button` renders button_to's form with `turbo_confirm`
- **Shortcut and hint:** `shortcut:` renders `kbd` elements; `hint:` text.
- **`command_palette_button`:** targets the dialog id and carries
  `aria-haspopup`.
- **`command_palette_results`:** wraps itself in the requested frame.
- **`ArgumentError`:** no groups and no `src:`.

## Preview

Mount the palette in the preview layout, with a "Search ⌘K" button in the
header nav. Commands navigate between the preview pages, open the profile
dialog through the modal frame, fire a flash toast, and confirm-then-delete the
profile. `src:` searches the preview's `Thing` records.

Check by hand:
- ⌘K on macOS, Ctrl+K elsewhere; "k" typed in a textarea doesn't open it.
- Arrow through groups, then Enter on:
  - a page link (a Turbo visit)
  - a modal link (the modal opens after the palette closes)
  - a confirm button (the confirm dialog appears and cancelling returns to the
    page)
- Escape clears, then closes; focus returns to the trigger.
- Back and forward after running a command never show the palette open.
- Dark theme, reduced motion, and VoiceOver announcing the active command and
  the count.

## Open questions

1. **Does `hotkey.md` provide a shared key-parsing module the palette
   imports?** If so, `mod` must be defined there.
2. **⌘Enter to open a link in a new tab:** worth having, or is it scope creep?
3. **Recent commands** (remembered in `localStorage`, shown for an empty
   query): in or out? That would be the first persisted client state beyond
   `tabs`' `sessionStorage`.
4. **One palette per layout** is assumed. Should contextual commands come
   from the page, e.g. `content_for :commands`, rendered into a group?
