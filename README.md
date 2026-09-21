# Unmagic::Components

Declarative table and detail-list builders for server-rendered Rails views, in
the spirit of `form_for`: describe the columns, get the chrome.

```erb
<%= table_for @users do |table| %>
  <% table.empty "No team members yet." %>

  <% table.column "Name", width: "38%" do |user| %>
    <%= link_to user.name, user %>
  <% end %>

  <% table.column "Created", sort: :created_at, direction: :desc do |user| %>
    <%= user.created_at.to_fs(:short) %>
  <% end %>

  <% table.column "Logins", :sign_in_count, numeric: true %>
<% end %>
```

## Features

- **Tables that stack on a phone**, each row a card of its cells with the
  headings written in front.
- **Sortable headers** that toggle `?sort`/`?direction`, carry `aria-sort`, and
  preserve the rest of the query string.
- **Deferred tables** — `defer: true` renders a skeleton inside a Turbo Frame
  without touching the collection, then loads the real rows into it. The
  skeleton keeps the loaded table's headers and column widths, so nothing shifts
  when the data lands.
- **Two flavours of empty state**: a blank slate for an empty dataset, and a
  separate one for a search that matched nothing, chosen automatically.
- **Companion detail rows** under any record, skipped per row when empty.
- **Detail lists** in inline and stacked layouts, with blanks rendered as an em
  dash so call sites don't each need `.presence || "—"`.
- **Dialogs** as native `<dialog>`s: a shared modal that loads its content from
  the server with a skeleton, an error panel with retry, and a close that lands
  in the same render as the page's refresh; same-page dialogs; and a confirm
  dialog in place of `window.confirm`.
- **AI chat components** for rendering an agent's work: a transcript, streamed
  replies revealed at a steady pace, tool calls strung into a timeline,
  reasoning, plans, workspaces, permission gates, questions, inline proposals,
  citations and a composer with Send and Stop. See [AI chat](#ai-chat).
- **Drag-and-drop ordering** by pointer or keyboard: sortable lists and a
  Trello-style board, posting one-row moves that
  [unmagic-sortable](https://github.com/unreasonable-magic/unmagic-sortable)
  saves. See [Sortable lists and boards](#sortable-lists-and-boards).
- **No hard dependency** on a pagination library or on any helper of yours.

## Installation

```ruby
gem "unmagic-components"
```

The components are styled with **Tailwind CSS v4, which your app needs**. The
gem's styles are a Tailwind source file,
`app/assets/tailwind/unmagic_components/engine.css`, that your own Tailwind
build compiles. Markup inside an installed gem is never scanned, so the gem
hands Tailwind its CSS instead of relying on scanning.

With tailwindcss-rails, import the engine's entry file after Tailwind itself in
`app/assets/tailwind/application.css`:

```css
@import "tailwindcss";
@import "../builds/tailwind/unmagic_components";
```

tailwindcss-rails generates that entry file on every build and watch, or on
demand with `bin/rails tailwindcss:engines`.

With the Tailwind CLI or an npm build, import the gem's file by path. `bundle
show unmagic-components` prints where the gem is installed:

```css
@import "tailwindcss";
@import "/path/to/unmagic-components/app/assets/tailwind/unmagic_components/engine.css";
```

The gem brings two of its siblings with it: `unmagic-icon`, which renders the
glyphs, and `unmagic-color`, which picks avatar tints. The glyphs are a subset of
Lucide shipped inside this gem, so there is no icon set to download; under Rails
they are also available to your views as `unmagic_icon
"unmagic_components:lucide/<name>"`.

The engine mixes the helpers into ActionView automatically — no initializer
needed to get started. The interactive components need their JavaScript too; with
importmap-rails the engine pins it for you, so add `import "unmagic/components"`
to your application.js (see [Dialogs](#dialogs)).

### Browsing components

`Unmagic::Components::Browser` is an engine for looking through every component,
its examples and their source inside your own app. Mount it in your routes:

```ruby
mount Unmagic::Components::Browser::Engine => "/unmagic/components" if Rails.env.development?
```

It brings its own stylesheet, prebuilt with Tailwind's default theme, and loads
the components' JavaScript and Turbo itself, so nothing in your CSS or JS
changes. It needs `turbo-rails` in your bundle. It shows the components as the
gem draws them: your configuration doesn't apply inside it, so an `empty_state`
that renders your own partial runs only in your app.

Its controllers inherit `ActionController::Base`, so your authentication doesn't
cover it. Its demo endpoints only write to the visitor's session, but mount it
outside development only behind a constraint of your own:

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount Unmagic::Components::Browser::Engine => "/unmagic/components"
end
```

### A static copy of the browser

`rake browser:export[site,/unmagic-components]` writes every page out as
static files under `site/`, with the stylesheet, the components' JavaScript and
Turbo beside them, for hosting where nothing runs. The second argument is the
path the site will be served under (a project site on GitHub Pages lives under
`/<repo>/`), which is what every link and asset URL in the pages is written
for. Examples that talk to a server (a form that saves, a search) say so on the
static page; the rest work as they do live. The theme toggle works too, kept in
the visitor's browser.

`.github/workflows/browser.yml` does this on every push to `main` and on every
pull request: `main` goes to the root of the repository's GitHub Pages site and
each pull request to `pr-<number>/`, with a comment on the pull request saying
where. Pages has to be set to deploy from the `gh-pages` branch.

## Theming

The components use Tailwind's own palette (neutral for surfaces, borders and
text, and red, green and amber for tones), with a `dark:` variant for every
colour. They look right with Tailwind's defaults and follow your theme from
there.

**Dark mode** follows your app's `dark` variant. Tailwind's default is the
visitor's system setting. To switch on a class or an attribute instead, redefine
the variant in your Tailwind input file and the components switch with it:

```css
@custom-variant dark (&:where(.dark, .dark *));
```

**Colours, radii and fonts** come from your theme, so change them there and the
components follow:

```css
@theme {
  --color-neutral-900: oklch(0.21 0.03 265);
  --radius-md: 0.25rem;
}
```

**One component** takes utilities through `class:`, like any other option.
The gem's rules sit in `@layer components`, which Tailwind orders before
`@layer utilities`, so your utilities win:

```erb
<%= card title: "Members", class: "rounded-none shadow-none" do %>…<% end %>
<%= form.field :email, "Email", class: "font-mono" %>
```

## Configuration

Seams, each with a working default. Point them at your own versions if you
already own these concerns:

```ruby
# config/initializers/unmagic_components.rb
Unmagic::Components.configure do |config|
  # The table's blank slate. Called with (view, content, **options), where the
  # options are whatever `table.empty` was given beyond its text.
  config.empty_state = ->(view, content, **options) { view.empty_state(content) }

  # The table's pager. Called with (view, pagy:, turbo_frame:).
  config.pagination = ->(view, pagy:, turbo_frame:) {
    view.render "shared/pagination", pagy: pagy, turbo_frame: turbo_frame
  }

  # Resolves the pager object a table pages with. Called with (view, collection);
  # return nil to suppress the pager. Nothing here is Pagy-specific — the
  # renderer only needs something answering previous/next/page_url, so
  # geared_pagination or your own object works just as well.
  config.pagy_for = ->(view, collection) { view.table_pagy(collection) }

  # Colours a block of source. Called with (source, language); return one
  # html_safe string per line. The default is Rouge, whose token classes the
  # gem's stylesheet colours.
  config.highlight = ->(source, language) { MyHighlighter.lines(source, language) }

  # Frames a block of code: a tool call's payload, a code block in prose. Called
  # with (view, source, language); return markup. The default is a code_view.
  config.code_block = ->(view, source, language) { view.render("code", source: source, language: language) }

  # What a sortable item carries for a record, and where drops post. The
  # unmagic-sortable gem sets both to its signed keys and endpoint.
  config.sortable_item = ->(view, record) { { key: record.to_param, rank: record.sortable_rank } }
  config.sortable_url = ->(view) { view.reorder_path }
end
```

## Usage

### `table_for(collection, **options, &block)`

| Option | Default | Meaning |
|---|---|---|
| `defer:` | `false` | Render a skeleton in a Turbo Frame first, then load the rows |
| `id:` | `"#{controller_name}_table"` | The frame id, when deferring |
| `paginate:` | `true` | `false` suppresses the pager; a pagy object is used directly |
| `headers:` | `true` | `false` omits the `<thead>` |
| `sorted_by:` | `params[:sort]` | The currently applied sort key |
| `sort_direction:` | `params[:direction]` | `:asc` or `:desc` |
| `sort_url:` | — | `->(key, direction) { url }`, when sorting rides on other params |
| `row_class:` | — | `->(record) { "…" }` for extra `<tr>` classes |

Any other option rides on the `<table>` itself — `class:`, `data:`, `aria-*` — so a
view can space or annotate the table without wrapping it in a div. `id:` is the
exception: it names the deferred turbo frame, not the table.

On the yielded builder:

- `column(title = nil, attribute = nil, **options, &block)` — content comes from
  the block, else `record.public_send(attribute)`. Options: `sort:`,
  `direction:`, `align:` (`:right`/`:center`), `numeric:` (right-aligns and uses
  tabular figures), `width:`, `class:`.
- `details(&block)` — a full-width companion row per record; capturing nothing
  skips it.
- `empty(text = nil, **options, &block)` — the blank slate for an empty dataset.
- `no_results(text = nil, **options, &block)` — shown instead when the collection
  responds to `filtered?` with true.

Extra options on `empty`/`no_results` are handed to the configured `empty_state`
seam, so an app whose blank slate takes more than a message can ask for it per
table:

```erb
<% table.empty "No labels yet.", icon: "tag" %>
```

```ruby
config.empty_state = ->(view, content, **options) do
  view.render "shared/empty", icon: options.fetch(:icon, "table"), message: content
end
```

`width:` takes a CSS length (`"40%"`, `"170px"`), which rides on a `<col>` as a
style, or any other string, which is used as a class name so a Tailwind app can
pass `"w-[40%]"`. Any width switches the table to a fixed layout. Give every
column of a deferred table a width, so the skeleton and the rows that replace it
lay out identically.

### `detail_list(variant: :inline, **options, &block)`

```erb
<%= detail_list variant: :stacked do |list| %>
  <% list.item "Client ID", @application.uid, class: "font-mono" %>
  <% list.item "Redirect URIs", span: :full do %>
    <% @application.redirect_uris.each do |uri| %>
      <div><%= uri %></div>
    <% end %>
  <% end %>
  <% list.item "Registered", @application.created_at %>
<% end %>
```

`:inline` lays labels beside values in a two-column grid; `:stacked` puts small
caps labels above values, in two columns once there is room. An item's `class:`
lands on its `<dd>`, and `span: :full` stretches a stacked item across both
columns.

### `table_tag(headers, rows, **options)`

The primitive the table is built on, for a static table that wants the same look
without the record/sort/pagination machinery:

```erb
<%= table_tag [ "Name", "Score" ], [ [ "Ann", 42 ], [ "Bob", 7 ] ], aligns: [ nil, :right ] %>
```

A cell is a value, or a `{ content:, **attrs }` hash setting attributes on its
`th`/`td`. A row is an array of cells, or a `{ cells:, **attrs }` hash setting
attributes on its `<tr>`. `aligns:` and `widths:` are per-column, and `caption:`
adds a screen-reader-only caption.

## Forms

`FormBuilder` is the chrome around a control — the wrapper, the label and its
required marker, the hint, and the error line — the part every app writes the same
way and then repeats in every view.

```erb
<%= form_with model: @label, builder: Unmagic::Components::FormBuilder do |form| %>
  <%= form.errors_summary %>
  <%= form.field :name, "Name", required: true, hint: "A key is derived from it." %>
  <%= form.field :colour, "Colour" do %>
    <%= form.select :colour, Label::COLOURS %>
  <% end %>
  <%= form.submit "Add label" %>
<% end %>
```

Set it as the default with `config.action_view.default_form_builder`, or pass
`builder:` per form.

- `field(method, label, required:, hint:, as:, &block)` — the control comes from
  `as:` (any builder method), or from the block when you pass one. An invalid field
  gets `aria-invalid="true"` and its errors underneath, read as a sentence.
- `group(inline: false)` — lay the contained fields out in a row.
- `errors_summary` — the record's whole-object (`:base`) errors.
- `check_box_field`, `check_box_collection` — a checkbox with its label beside it.
- `submit` — conjugates its label for the length of the submit ("Save" → "Saving…",
  "Add label" → "Adding label…") via `data-turbo-submits-with`. Pass
  `submitting: false` to leave it alone, or a string to choose it. A block supplies
  your own button content, e.g. an icon.
- `form_value_for` — the value to show, whether the object is a model or something
  hash-ish, preferring what the user actually typed.
- `autogrow_text_area` — a textarea that grows as you type, from the height its
  `rows` give it up to its CSS `max-height`, and then scrolls. Use it as a
  field's control with `form.field :body, "Message", as: :autogrow_text_area`.
  Outside a form builder, use `autogrow_text_area_tag`. Needs
  `import "unmagic/components/autogrow"`.
- `uuid_field` — a hidden field holding a fresh UUIDv7. Use it when the form
  should submit an id the client already knows, such as the id of an element
  rendered before the server replies. A new id is generated when the page loads
  and every time the form resets; without JavaScript the server's own id is sent.
  Outside a form builder, use `uuid_input_tag`. Needs
  `import "unmagic/components/uuid_input"`.

**The controls are styled too.** Each control the builder makes wears a class for
its kind, and the gem's CSS styles those classes, never bare elements, so an input
the gem didn't render keeps whatever your app gives it:

| Builder methods | Kind | Class |
|---|---|---|
| `text_field`, `email_field`, `number_field`, `url_field`, `search_field`, `telephone_field` | `:input` | `UnmagicInput` |
| `password_field` | `:password` | `UnmagicInput` |
| `text_area`, `autogrow_text_area` | `:text_area` | `UnmagicInput` |
| `date_field`, `time_field`, `datetime_field`, `month_field`, `week_field` | `:date` | `UnmagicInput` |
| `select`, `collection_select`, `grouped_collection_select`, `time_zone_select` | `:select` | `UnmagicSelect` |
| `check_box_field`, `check_box_collection` | `:check` | `UnmagicCheck` |

A class you pass (`class: "font-mono"`) is added after the gem's. Rails' own
`check_box` and `radio_button` are left alone, as are the `*_tag` helpers. Give
one of those the same look with `control_classes`:

```erb
<%= select_tag "status", options_for_select(%w[Open Closed]), class: control_classes(:select) %>
<%= search_field_tag "q", params[:q], class: control_classes(:input, size: :small) %>
<%= radio_button_tag "notify", "daily", class: control_classes(:radio) %>
```

`control_classes(kind, size:)` takes the kinds above plus `:radio`. `size:
:small` or `:large` sits a box level with a `button_classes` button of the same
size.

The classes come from a seam. If your app already styles its inputs, point it at
your own classes, or return `nil` to leave the controls unstyled:

```ruby
config.control_class = ->(_view, kind) { kind == :select ? "form-select" : "form-input" }
config.control_class = ->(_view, _kind) { nil }
```

The controls use the same palette as the rest of the gem. A checked box or radio
is neutral-900 (neutral-100 in dark mode), and an invalid control has a red
border.

The submit button's classes come from a seam, so it wears your own button:

```ruby
config.submit_class = ->(_view, variant) { variant == :primary ? "btn btn-primary" : "btn" }
```

### Switches, radios, sliders, passwords and codes

```erb
<%= form.switch_field :notify, "Email me about new replies", hint: "…" %>
<%= form.radio_button_collection :plan, Plan.all, :id, :name, legend: "Plan", hint_method: :summary, variant: :cards, inline: true %>
<%= form.field :volume, "Volume", as: :range_field, min: 0, max: 100 %>
<%= form.field :password, "Password", as: :password_field, reveal: true %>
<%= form.field :code, "Code", as: :one_time_code_field, length: 6, submit: true %>
```

- `switch_field` is a checkbox with `role="switch"`, drawn as one; `switch` is
  the bare control and `switch_tag` the tag form.
- `radio_button_collection` renders a fieldset named by `legend:`, a hint under
  each option from `hint_method:`, `inline:` in a row, and `variant: :cards`
  where the whole card is the target. `radio_button_field` is one labelled radio.
- `range_field` is the native slider styled to match.
- `password_field reveal: true` adds a button that shows what was typed
  (`import "unmagic/components/password"`); `password_field_tag` takes it too.
- `one_time_code_field` is one real input for a code, drawn as a row of boxes
  by `import "unmagic/components/one_time_code"`, so paste and autofill work;
  `length:` 4 to 10, `charset: :numeric` or `:alphanumeric`, `submit: true` to
  submit on the last character.

### `input_group(prefix:, suffix:, **options, &block)`

A control with something joined to either end: `input_group prefix: "https://",
suffix: ".example.com" do … end`. Text becomes a tinted addon; markup (a
button, an icon) is set in as it is.

### `toggle(label, pressed:, icon:, name:, …)` and `toggle_group(name:, value:, multiple:, label:, …, &block)`

A button that is on or off, and a run of them joined into a segmented control
a form submits. With a `name:` a toggle is a checkbox drawn as a button and
needs no script; without one it is a button whose `aria-pressed` the script
flips (`import "unmagic/components/toggle"`). A group's options are native
radios, or checkboxes with `multiple: true`, so the arrow keys move the choice.

## Live tables

A table whose rows a Turbo Stream keeps up to date needs the column definitions in
a place both the page render and a single broadcast row can reach, so they move
into a partial that takes a `table` local and does nothing but declare them:

```erb
<%# tasks/_columns.html.erb %>
<% table.column "Task", width: "30%" do |task| %>
  <%= link_to task.kind, task %>
<% end %>
<% table.column "Status" do |task| %>
  <span class="badge"><%= task.status %></span>
<% end %>
```

The page renders the table with them, names the `<tbody>` so a stream can target
it, and gives the rows one id prefix:

```erb
<%= turbo_stream_from "tasks" %>

<%= table_for @tasks, columns: "tasks/columns", rows_id: "task_rows",
      row_id: ->(task) { "task_#{task.id}" } do |table| %>
  <% table.empty "Nothing has run yet." %>
<% end %>
```

A broadcast renders one row from the same partial:

```erb
<%# tasks/_row.html.erb %>
<%= row_for task, columns: "tasks/columns", row_id: ->(task) { "task_#{task.id}" } %>
```

```ruby
class Task < ApplicationRecord
  after_create_commit :broadcast_row
  after_update_commit :broadcast_row

  private
    def broadcast_row
      broadcast_action_to "tasks", action: :upsert, target: "task_rows",
        attributes: { order: "desc" }, partial: "tasks/row", locals: { task: self }
    end
end
```

`upsert` is a Turbo Stream action this gem ships. Import it once:

```js
// app/javascript/application.js
import "unmagic/components/upsert"
```

It merges `append` and `replace`. If an element with the incoming id is already in
the document it is replaced in place, so a record that is both server-rendered and
broadcast never duplicates. Otherwise it is inserted at the position its id sorts
to, so out-of-order delivery still lands in order — which assumes time-ordered ids
(UUIDv7, ULID). `order="desc"` flips the comparison for a newest-first list.

**`row_id:` matters over an STI collection.** `dom_id` names the record's own
class, so subclasses get different prefixes and the rows sort by type rather than
by id. Give every row one prefix and the time-ordered id decides.

The companion `details` row is not broadcast: a stream action carries one element,
and the pair is a page-render concern.

## Dialogs

There are three kinds, all built on the same panel: a modal whose content loads
from the server, a dialog that's already on the page, and a confirm that replaces
`window.confirm`. Each is a native `<dialog>`, so the browser handles trapping
focus, closing on Escape, and returning focus when it closes.

Import the behaviour once:

```js
// app/javascript/application.js
import "unmagic/components"        // every component, including the confirm dialog

// ...or only the ones you want
import "unmagic/components/modal"
import "unmagic/components/confirm"
```

### The shared modal

Mount it once, in the layout:

```erb
<%= modal_frame %>
```

Point a link at any action with `modal_link_to`. It takes `link_to`'s arguments:

```erb
<%= modal_link_to "Edit", edit_label_path(@label), class: button_classes %>
```

The action renders a `dialog`. It's the same template whether the page opens in
the modal or is visited directly:

```erb
<%# labels/edit.html.erb %>
<%= dialog title: "Edit label", form: { model: @label } do |dialog, form| %>
  <%= form.field :name, "Name", required: true %>

  <% dialog.footer do %>
    <button type="button" class="<%= button_classes %>" data-unmagic-dialog-close>Cancel</button>
    <%= form.submit "Save" %>
  <% end %>
<% end %>
```

```ruby
class LabelsController < ApplicationController
  include Unmagic::Components::DialogResponder

  def update
    if @label.update(label_params)
      refresh_or_redirect labels_path, notice: "Label saved."
    else
      render :edit, status: :unprocessable_content
    end
  end
end
```

What that gets you:

- **Opening:** the dialog opens as soon as the request starts and shows a skeleton
  until the response arrives. Turbo's hover prefetch doesn't open it.
- **Failed loads:** a network error, an error status or an empty `head :forbidden`
  all show an error panel with a Try again button, rather than Turbo's
  "Content missing".
- **Failed saves:** a `:unprocessable_content` render replaces the form inside the
  dialog, errors and all.
- **Successful saves:**
  - `refresh_or_redirect`: the dialog stays up, with its submit button still
    saying "Saving…". It closes in the same render as the morph refresh, so the
    page repaints once, straight to its new state.
  - A stream response that doesn't refresh: the dialog closes as soon as it's read.
  - A plain `redirect_to`: the modal visits that page and closes.
- **Multi-step forms:** a response that renders back into the frame, such as the
  next step of a wizard, keeps the dialog open.
- **Closing:** Escape, a click on the backdrop, or any
  `[data-unmagic-dialog-close]`. A drag that starts in an input and ends over the
  backdrop doesn't count, so selecting text never throws the form away.

Build the form with `form:` rather than wrapping the dialog in `form_with`. On a
request aimed at the modal the dialog wraps itself in the modal's turbo frame, and
Turbo keeps only what is inside that frame. A form outside the dialog would be
dropped.

The dialog leaves overflow visible, so a dropdown inside a form isn't clipped. The
catch is that a dialog's content has to be short enough to fit the screen.
`config.modal_frame_id` (default `"modal"`) renames the frame.

### A dialog already on the page

```erb
<%= dialog_button "What's a scope?", dialog: "scopes_help", class: button_classes(:ghost) %>

<%= dialog_tag "scopes_help", title: "Scopes" do %>
  <p>A scope limits what a token can do.</p>
<% end %>
```

The block is yielded the panel, for a `footer`. Extra options go on the
`<dialog>`.

### Confirm

Importing `unmagic/components/confirm` replaces the browser's confirm box for
`data-turbo-confirm` with a dialog in the same chrome:

```erb
<%= button_to "Delete", label_path(@label), method: :delete, class: button_classes(:danger),
      form: { data: { turbo_confirm: "Delete this label?",
                      turbo_confirm_accept: "Delete",
                      turbo_confirm_variant: "danger" } } %>
```

- `data-turbo-confirm-title` sets the heading.
- `data-turbo-confirm-accept` sets the confirming button's label.
- `data-turbo-confirm-variant="danger"` makes that button red and focuses Cancel
  instead, so a destructive action is never one Enter away.

These attributes are read from the submitter, then the form. A link with
`data-turbo-method` doesn't pass them on: Turbo builds a form for it and copies
only `data-turbo-confirm` onto it. Use `button_to` when you need them.

### Buttons

`button(label = nil, variant = :default, **options, &block)` is a button, a link
that looks like one, or a `button_to` form, from one call:

```erb
<%= button "Save", :primary, type: "submit" %>
<%= button "New label", href: new_label_path, icon: :plus %>
<%= button "Delete", :danger, href: label_path(@label), method: :delete, form: { data: { turbo_confirm: "Sure?" } } %>
<%= button "Close", :icon, icon: :x %>
<%= button "Saving", :primary, loading: true %>
```

The variants are `:default`, `:primary`, `:ghost`, `:danger` and `:icon`; the
sizes `size: :small` and `:large`. `href:` renders a link, and with a `method:`
other than GET a `button_to` whose `form:` and `params:` pass through. `icon:` is
a symbol from the gem's Lucide set or your own markup, and leads the label; the
`:icon` variant shows only the icon and keeps the label for a screen reader and
a hover. `loading: true` disables the button and turns a spinner in the icon's
place. `disabled: true` disables a button, and marks a link `aria-disabled` and
takes it out of the tab order. `block: true` fills the width. Every button is at
least 44px tall where the pointer is coarse.

`button_group(label:, orientation:, **options) { |group| … }` joins buttons edge
to edge into one control; `group.button` takes the arguments above and
`group.item` anything else that belongs in the run. `orientation: :vertical`
stacks them.

`button_classes(variant = :default, size: nil)` returns the class string alone,
for `link_to`, `button_to` and `form.submit`.

### Translations

The words in these components go through I18n, with English defaults. The confirm
dialog is built in the browser, so render `<%= confirm_dialog_template %>` once in
your layout to translate it.

| Key | Default |
|---|---|
| `unmagic.components.dialog.close` | Close |
| `unmagic.components.modal.loading` | Loading… |
| `unmagic.components.modal.error_title` | Couldn’t load |
| `unmagic.components.modal.error_message` | Something went wrong loading this. Check your connection and try again. |
| `unmagic.components.modal.retry` | Try again |
| `unmagic.components.confirm.title` | Are you sure? |
| `unmagic.components.confirm.accept` | Confirm |
| `unmagic.components.confirm.cancel` | Cancel |

## Page building blocks

Plain Ruby and CSS, with no JavaScript.

### `page_header(title:, description:, back:, **options, &block)`

```erb
<%= page_header title: @label.name, description: "Applied to 12 issues.",
      back: { text: "Labels", path: labels_path } do |header| %>
  <% header.badge "Archived", tone: :warn if @label.archived? %>
  <%= modal_link_to "Edit", edit_label_path(@label), class: button_classes %>
<% end %>
```

The block's output becomes the actions on the right. Its builder also takes
`title { }` and `description { }` for markup, and `leading { }` for something
before the title, such as an avatar. The actions drop below the title when there
isn't room beside it.

### `section(title, spacing: :normal, heading: :h2, **options, &block)`

```erb
<%= section "Files" do |section| %>
  <% section.aside { badge "12" } %>
  <% section.actions { button "Upload", href: new_upload_path, size: :small } %>
  <%= table_for @files do |table| %>...<% end %>
<% end %>
```

A titled run of a page. `aside` is what qualifies the title, `actions` the
button that acts on the whole run, hard right; on a narrow screen it drops
under the heading. `spacing: :tight` closes up the first run on a page, `:none`
leaves it to you.

### `item(title:, description:, href:, mono:, **options, &block)`

```erb
<%= item title: file.name, description: "#{file.content_type} · #{size}", href: file_path(file), mono: true do |item| %>
  <% item.media { image_tag file.thumbnail } %>
  <% item.meta { badge "Hidden" } %>
  <% item.actions { menu … } %>
<% end %>
```

A row about one thing, wherever a list shows it: `media` on the left, the title
over its description, `meta` flags beside the title, `actions` on the right, and
the block under the description. `href:` makes the title a link whose hit area
is the whole row, leaving the actions clickable on their own.

### `chart(series, labels:, type: :column, format: :count, title:, width:, legend:, table:, max:, label_format:, **options)`

```erb
<%= chart [ { label: "Spent", values: spend_by_day } ], labels: days, format: :money, title: "Spend" %>
<%= chart [ { label: "CPU", values: readings } ], labels: times, type: :line, format: :percent, max: 100 %>
```

A chart drawn as inline SVG with no script. `labels:` are the columns or the
points along a line; each series is `{ label:, values: }` with values keyed by
label or an array in the same order, and an optional `total:` for the legend.
Columns stack where there is more than one series; on a line a nil value is a
gap. `format:` is `:count`, `:money` or `:percent`. Every column carries a
tooltip, and the numbers are laid out as a table under "As a table". Colours
come from the stylesheet by slot (`--unmagic-chart-series-1` to `-6`), so a
series is the same colour on every chart. `width:` is the drawing's own width
(720), which scales to its box.

### `card(title:, href:, flush:, **options, &block)`

```erb
<%= card title: "Members" do |card| %>
  <% card.actions { link_to "Invite", new_invitation_path, class: button_classes(size: :small) } %>
  Ada, Grace and Katherine can see everything.
  <% card.footer { "3 of 5 seats used" } %>
<% end %>
```

- `flush: true` removes the body's padding. A `table_tag` or `table_for` inside a
  flush card uses the card's border instead of drawing its own.
- `card.header { … }` is a bar of your own across the top, ruled off from the
  body, in place of a title: a row of tabs, a search field, a run of badges. Its
  options go on the `<header>`. `border: false` and `background: false` take
  those away, for a card nested in another surface.
- `href:` makes the whole card one link, for a row that opens a record. Don't put
  other links or buttons inside it.
- A card doesn't clip its content, so a dropdown inside one isn't cut off.

### `badge(content, tone: :neutral, **options)`

```erb
<%= badge "Draft" %>
<%= badge "Overdue", tone: :bad %>
```

Tones are `:neutral`, `:good`, `:warn`, `:bad`, `:info` (outlined) and `:accent`.

### `callout(title = nil, tone: :neutral, badge: nil, icon: true, **options, &block)`

```erb
<%= callout "DNS isn't verified", tone: :warn, badge: "Pending" do %>
  Add the TXT record below, then check again.
<% end %>
```

This is for the state of something in place, such as a health check or a warning
above a form. Each tone except `:neutral` has an icon, and `icon: false` removes
it. A badge takes the callout's tone.

### `pagination(pager, window: 2, turbo_frame: nil, label: nil, **options)`

Links to the pages around this one, for anything that pages like Pagy. The
pager answers `previous`, `next` and `page_url`; one that also answers `page`
and `last` gets numbered links, `window:` pages either side of this one with the
first and last always shown. On a phone the numbers give way to "6 of 12". One
page renders nothing. This is what `table_for` draws under itself through
`config.pagination`.

### `breadcrumbs(label: nil, **options, &block)`

```erb
<%= breadcrumbs do |crumbs| %>
  <% crumbs.link "Settings", settings_path %>
  <% crumbs.current "GitHub" %>
<% end %>
```

The trail of pages above this one. `crumbs.link` takes `link_to`'s arguments;
`crumbs.current` is optional and last. On a phone only the last two crumbs
show. `page_header` takes the same block as its `breadcrumbs` part, where
`back:` goes; `mono: true` on a page header sets its title in monospace.

### `tree_view(label:, guides: true, **options, &block)`

```erb
<%= tree_view label: "Files" do |tree| %>
  <% tree.branch "app", icon: :folder do |app| %>
    <% app.leaf "user.rb", href: blob_path("app/models/user.rb"), icon: :file_code, current: true %>
  <% end %>
  <% tree.leaf "Gemfile", href: blob_path("Gemfile"), icon: :file %>
<% end %>
```

A nested, collapsible list of things inside other things: nested lists and
`<details>`, so Tab moves through the open rows and Enter or Space folds a
branch, with no script. `label:` names the root list and is required;
`guides: false` drops the line beside each level.

- **`tree.branch(label, icon:, open:, meta:)`** yields a builder with the same
  `branch` and `leaf`, to any depth. It starts open when a leaf inside it is
  current, unless `open:` says otherwise. A branch with nothing in it says
  "Empty".
- **`tree.leaf(label, href:, icon:, current:, meta:)`** is a link with `href:`
  and plain text without; a block gives it markup in place of `label`.
  `current: true` marks it `aria-current="page"`.
- **`meta:`** is a short reading (a size, a count) kept whole at the end of the
  row while the label truncates. `icon:` is one of the gem's icons; none by
  default.
- Other options on a branch or a leaf go on its row, and a string label is the
  row's `title`. Other options on `tree_view` go on the root `<ul>`. An empty
  tree renders nothing.

I18n: `unmagic.components.tree.empty`.

### `kbd(*keys, hotkey: nil, sequence: false, **options)`

A key or a combination drawn as key caps: `kbd "Esc"`, `kbd :mod, "K"`,
`kbd hotkey: "mod+shift+p"`, `kbd "G", "I", sequence: true`. Named keys draw
glyphs and carry their spoken names; `:mod` is ⌘ on Apple platforms and Ctrl
elsewhere.

### `empty_state(content = nil, title: nil, icon: nil, **options, &block)`

```erb
<%= empty_state "Import a folder or drop files here.", title: "No files yet", icon: :folder do %>
  <%= button "Import", :primary, href: new_import_path %>
<% end %>
```

`content` says what's missing; `title:` heads it, `icon:` is a glyph above that,
and the block is the actions that fix it. All of it goes through
`config.empty_state`, so a table's blank slate and this one match.


```erb
<%= empty_state "No invitations yet." %>
```

This is the same blank slate tables use. It renders through the `empty_state`
setting, so if your app replaces it, both change.

## Times and tooltips

### `local_time_tag(time, format: :medium, compact: false, **options)`

```erb
<%= local_time_tag comment.created_at, format: :relative %>   <%# "3 hours ago" %>
<%= local_time_tag invoice.due_at, format: :date %>           <%# "16 Sept 2026" %>
<%= local_time_tag event.starts_at %>                         <%# "16 Sept 2026, 4:33 pm" %>
```

The browser formats the time with `Intl`, in the viewer's own locale and time
zone, so there's nothing to translate and no time zone to look up for the user.
Until the script runs, the server's own rendering (in `Time.zone`) shows instead.

| `format:` | Shows |
|---|---|
| `:short`, `:medium`, `:long`, `:full` | A date and time, in increasing detail |
| `:date`, `:time` | Just one of them |
| `:relative` | "now", "5 minutes ago", "yesterday", "in 3 days" |

- **Relative times stay current.** Every relative time on the page updates on one
  shared timer, once a minute, and the full time shows on hover.
- **Days follow the calendar.** A relative time counts days by midnight, so
  something from 11pm reads "yesterday" at 2am.
- **Old dates settle.** Past a week a relative time becomes a plain date and stops
  updating.
- **Compact form:** `compact: true` shortens a relative time to "5m" or "3h".
- **Blank values:** a `nil` time renders an em dash.

### `tooltip(content = nil, text:, placement: :top, term: nil, **options, &block)`

```erb
Every page declares a <%= tooltip "canonical URL", text: "The address search engines treat as the original." %>.

<%= tooltip text: "Copy the key" do %>
  <%= copy_button @key.secret %>
<% end %>
```

- **Hover and focus:** the hint appears on hover after a short delay, or straight
  away on focus. Escape dismisses it.
- **Never clipped:** it's drawn in the browser's top layer, so a container's
  overflow can't cut it off. It flips to the other side when there isn't room and
  stays inside the screen.
- **Terms:** plain text content gets a dashed underline and a help cursor, and
  becomes focusable. Block content, such as a button or an icon, is left alone
  and the hint describes its focusable element. `term:` overrides that choice.
- **Placement:** `:top` or `:bottom`.

Needs `import "unmagic/components/time"` and `"unmagic/components/tooltip"`, or
`import "unmagic/components"`.

## Menus, tabs, copy buttons and code

### `menu(label = nil, align: :end, **options, &block)`

On the Popover API since 0.6.0: the panel is in the top layer and the trigger
opens it without script. `menu.section` heads the items after it, `menu.item`
is a plain button for wiring, `menu.disclosure` folds a small form out in
place, and `icon:` leads a label. On a narrow screen the panel is a sheet along
the bottom.

```erb
<%= menu do |menu| %>
  <% menu.link "Edit", edit_job_path(@job) %>
  <% menu.divider %>
  <% menu.button "Delete", job_path(@job), method: :delete, tone: :danger,
       form: { data: { turbo_confirm: "Delete this job?" } } %>
<% end %>
```

- **Built on `<details>`:** the menu opens even before its script loads.
- **Closing:** an outside click, Escape, choosing an item, or navigating away with
  Turbo all close it.
- **Keyboard:** the arrow keys, Home and End move between items. Opening the menu
  with the keyboard focuses the first item.
- **Trigger:** with no label it's a ⋮ icon button labelled "More actions"
  (`unmagic.components.menu.label`). Pass a label for a text button with a chevron.
- **Items:** `link` and `button` take `link_to`'s and `button_to`'s arguments, plus
  `tone: :danger`.
- **Alignment:** `align: :start` lines the panel up with the trigger's left edge
  instead of its right.

### `sidebar(id:, label: nil, collapse_below: :lg, **options, &block)` and `sidebar_toggle(id)`

```erb
<%= sidebar id: "app_nav" do |nav| %>
  <% nav.header { link_to image_tag("logo.svg", alt: "Acme"), root_path } %>
  <% nav.section do |s| %>
    <% s.link "Inbox", inbox_path, icon: :messages_square, badge: @unread %>
  <% end %>
  <% nav.section "Settings", collapsible: true do |s| %>
    <% s.link "Members", members_path %>
  <% end %>
<% end %>
<%= sidebar_toggle "app_nav" %>
```

The navigation down the side of an app. One `<nav>` for both widths: a popover
sheet from the edge below `collapse_below:` that the toggle opens with no
script, inline above it. Needs `import "unmagic/components/sidebar"`.

### `navbar(label: nil, sticky: false, collapse: :md, **options, &block)`

The bar across the top: `nav.brand`, `nav.link … current:`, `nav.actions`. On a
narrow screen the links fold behind a menu button on a `<details>`. Needs
`import "unmagic/components/navbar"`.

### `combobox_tag(name, collection:, value:, text:, multiple:, selected:, src:, …)`, `form.combobox` and `combobox_results`

```erb
<%= form.field :owner_id, "Owner", as: :combobox, collection: @members, text: :name %>
<%= form.combobox :label_ids, collection: @labels, text: :name, multiple: true %>
<%= combobox_tag "owner_id", collection: [ @owner ].compact, text: :name, src: search_members_path %>
```

A text input that filters a list of options, choosing one or several. The value
is a hidden input (`name[]` with a chip per choice when multiple), so a form
submitted before script loads keeps it. With `src:` the rest of the list is
fetched as you type from an action answering `?q=` with `combobox_results`. A
block records rich options: `combobox.option value, label:, keywords: { markup }`.
Needs `import "unmagic/components/combobox"`.

### `command_palette(id:, hotkey: "mod+k", src:, …, &block)`, `command_palette_button` and `command_palette_results`

Render once in the layout. `palette.group "Go to" { |g| g.link …; g.button … }`;
each command holds a real link or `button_to` form, so frames and confirms
work. ⌘K opens it; `src:` fetches more commands as you type. Needs
`import "unmagic/components/command_palette"`.

### `context_menu(for:, label: nil, **options, &block)`

The same panel as `menu`, opened at the pointer on a right-click or a long press
on the element with the id `for:`, or at its corner on Shift+F10. The element
can sit anywhere, so a table row can have one. Keep the actions reachable
elsewhere too: without script the browser's own menu shows.

### `popover(label = nil, title: nil, placement: :bottom, align: :start, size: :default, **options, &block)`

```erb
<%= popover "Rename", title: "Rename" do |popover| %>
  <%= form_with model: @job, builder: Unmagic::Components::FormBuilder do |form| %>
    <%= form.field :name, "Name" %>
    <% popover.footer { form.submit "Rename" } %>
  <% end %>
<% end %>
```

A small panel of content behind a trigger. The label is a text trigger with a
chevron; `popover.trigger { … }` is a trigger of your own. The panel is a
`popover="auto"` dialog in the top layer, placed against the trigger by
`unmagic/components/position` and kept there while open; on a narrow screen it
is a sheet along the bottom. Needs `import "unmagic/components/popover"`.

### `disclosure(summary = nil, open: false, **options, &block)` and `accordion(id: nil, exclusive: false, **options, &block)`

A summary that folds a panel open, on `<details>`, and a run of them with
`exclusive: true` opening one at a time through the platform's own
`<details name>`. No script.

### `scroll_area(axis: :y, max_height: nil, label: nil, shadows: true, **options, &block)`

A box that scrolls, with shadows where there is more to see. `label:` makes it a
named region a keyboard can reach and scroll. Knob: `--unmagic-scroll-area-max-height`.

### Drawers

`dialog_tag … side: :end` (or `:start`) and `dialog … side:` open the panel as a
drawer along that edge of the screen; pass the same `side:` to `modal_link_to`
so the shared modal's skeleton opens there too. On a phone every dialog is a
sheet from the bottom. A dialog whose panel says `aria-busy="true"` refuses
Escape and the backdrop until it isn't.

### `tabs(id: nil, **options, &block)`

```erb
<%= tabs id: "response" do |tabs| %>
  <% tabs.tab "Body" %>
  <% tabs.tab "Headers" %>
  <% tabs.tab "Preview", disabled: "HTML only" %>
  <% tabs.panel do %>...<% end %>
  <% tabs.panel do %>...<% end %>
<% end %>
```

- **Accessible markup:** the server renders the full tab pattern with its ARIA
  roles, so only the selected tab is in the tab order. The arrow keys, Home and
  End switch tabs.
- **Panels:** each panel pairs with an enabled tab, in order. A tab with
  `disabled:` shows its reason and takes no panel, and `active: true` picks the
  tab shown first.
- **Icons:** `icon:` leads a label with a symbol from the gem's Lucide set
  (`:folder`) or rendered markup from your own icons.
- **Styles:** `style: :segmented` (the default) is an inset track with the
  chosen tab raised out of it. `style: :bar` is a row of pill tabs with no
  track, for a bar across a card or a page; on a narrow screen it scrolls
  sideways rather than wrapping, and the chosen tab is kept in view.
- **Remembering the choice:** give the tabs an `id:` and the chosen tab is kept
  for that page until the browser tab closes, even across a morph refresh.
  Each change fires `unmagic-tabs:change`.

Give each tab an `href:` instead of panels and you get a bar of links to separate
pages. It's rendered on the server with no script, and `active: true` marks the
current page:

```erb
<%= tabs do |tabs| %>
  <% tabs.tab "All", href: invitations_path, active: @status.nil? %>
  <% tabs.tab "Replied", href: invitations_path(status: "replied"), active: @status == "replied" %>
<% end %>
```

### `panel(id: nil, flush: false, **options, &block)`

A card with switcher buttons across its top bar and the open one's content
below: a README beside the brief, a file's source beside its preview.

```erb
<%= panel id: "notes" do |panel| %>
  <% panel.tab "README", icon: :book_open %>
  <% panel.tab "Agents", icon: :bot %>
  <% panel.panel { markdown @readme } %>
  <% panel.panel { markdown @agents } %>
<% end %>
```

The tabs are `tabs`' own, in the bar style: the same labels, icons, `disabled:`
reasons and `active:` choice, switched in the page. Give each an `href:` instead
and they are pages of their own: the server draws the open one, the block is its
body, and the address names the tab.

```erb
<%= panel flush: true do |panel| %>
  <% panel.tab "Source", href: file_path(@file, view: :source), active: @view == :source, icon: :code %>
  <% panel.tab "Preview", href: file_path(@file, view: :preview), active: @view == :preview, icon: :eye %>
  <%= render "files/#{@view}", file: @file %>
<% end %>
```

`flush: true` drops the body's padding, for a code view or a table that runs to
the edges. Other options go on the outer element. Needs
`import "unmagic/components/tabs"` for in-page tabs.

### `copy_button(text = nil, from: nil, label: nil, **options, &block)`

```erb
<%= copy_button @key.secret %>

<code id="install_command">bundle add unmagic-components</code>
<%= copy_button from: "install_command" do %>Copy command<% end %>
```

- **Feedback:** the copy icon briefly turns into a check, and screen readers hear
  "Copied".
- **Copying from the page:** `from:` copies the value of an input, or the text of
  any element, with that id at the moment of the click. The text doesn't need to
  be repeated in an attribute.
- **Labels and options:** without a block it's an icon button labelled `label:`
  ("Copy"). Other options go on the `<button>`.
- **Events:** it fires `unmagic-clipboard:copy`, or `unmagic-clipboard:error` when
  the browser refuses the write, so you can show a toast.

Needs `import "unmagic/components/menu"`, `"unmagic/components/tabs"` and
`"unmagic/components/clipboard"`, or `import "unmagic/components"`.

### `code_view(source, language: nil, lines: false, wrap: true, max_height: nil, copy: true, label: nil, id: nil, **options)`

A block of source to read or copy: a file, a payload, a command. Coloured with
Rouge, wrapping long lines, with a copy button in the corner that appears on
hover and stays put on a touch screen. Just the code; put it in a `panel` for a
switcher or a `card` for a title.

```erb
<%= code_view @file.source, language: @file.language %>
<%= code_view backtrace, language: :plaintext, lines: true, max_height: "20rem" %>
<%= code_view command, language: :shell, wrap: false, copy: false %>
```

`language:` is a name Rouge knows (`:json`, `"ruby"`, `:erb`) or a lexer;
unknown or `nil` is plain text. `lines: true` numbers the lines, and the numbers
are drawn rather than written, so a copy leaves them behind. `wrap: false`
scrolls sideways instead of wrapping. `max_height:` is a CSS length past which
the block scrolls, and a block that can scroll is a focusable region named
`label:` ("Code"). `id:` names the wrapper; the `<code>` is `"#{id}_code"`.
Colouring goes through `config.highlight`; `config.code_block`, which tool
payloads and prose code blocks render through, is a `code_view` by default.
Knob: `--unmagic-code-view-max-height`. I18n: `unmagic.components.code_view.label`.
Needs `import "unmagic/components/clipboard"` for the button.

## Separators, progress and spinners

### `separator(label = nil, orientation: :horizontal, **options)`

A rule between two things: a plain `<hr>`, one with a word on it (`separator
"or"`), or `orientation: :vertical` upright between items in a row.

### `progress(value = nil, max: 100, tone: :neutral, size: :medium, label: nil, indeterminate: false, **options)`

A bar filled to `value` out of `max`, in a tone (`:neutral`, `:good`, `:warn`,
`:bad`, `:info`) and a size (`:small`, `:medium`, `:large`), named `label:`
("Progress"). With `indeterminate: true`, or no value, it sweeps; under reduced
motion it pulses. I18n: `unmagic.components.progress.label`.

### `spinner(text = nil, label: nil, size: :medium, **options)`

A ring that turns while something loads. Visible text is the label and sits
beside the ring; otherwise `label:` ("Loading…") is read but not seen, and
`label: false` makes the ring decorative for a control that already says what is
happening. Sizes `:small`, `:medium`, `:large`. It pulses rather than turning
under reduced motion. I18n: `unmagic.components.spinner.label`.

## Skeletons

Skeletons block out an interface while it loads. `skeleton` yields a builder,
like `form_for` does. You arrange its shapes with your own markup:

```erb
<%= skeleton label: "Loading candidate" do |s| %>
  <div class="flex items-center gap-3">
    <%= s.circle size: "3rem" %>
    <div class="flex-1">
      <%= s.text width: "60%" %>
      <%= s.text width: "40%" %>
    </div>
  </div>
  <%= s.text lines: 2 %>
<% end %>
```

| Shape | Stands in for |
|---|---|
| `s.text(width:, lines:)` | A line of text in the surrounding font. `lines:` makes a paragraph with a shorter last line. |
| `s.circle(size:)` | An avatar or round icon (default `2.5rem`). |
| `s.block(height:, width:)` | An image, chart or map (default `8rem` tall, full width). |
| `s.button(size:, width:)` | A `button_classes` button, `size: :small` or `:large`. |

- **Nothing moves when content arrives.** Each shape is sized from what it
  replaces: a text line fills exactly one line of the font it sits in, so a line
  inside an `<h1>` is heading-sized, and a button shape matches a real button's
  height.
- **Styling:** every shape also takes `class:` and `style:`.
- **Screen readers:** the shapes are hidden from them. They hear `label:`
  ("Loading…", `unmagic.components.skeleton.loading`) once for the whole group.

Outside a block, the same shapes are `skeleton_text`, `skeleton_circle`,
`skeleton_block` and `skeleton_button`.

Some components render a skeleton version of themselves, so it matches the real
one:

```erb
<%= detail_list skeleton: true do |list| %>
  <% list.item "Created" %>
  <% list.item "Salary" %>
<% end %>

<%= page_header skeleton: true %>
<%= card title: "Members", skeleton: true %>
```

Anything you pass still renders for real, and the rest becomes shapes:

- **`detail_list`** keeps its labels and shows a bar for each value.
- **`page_header`** shows a title bar, a description line and a button.
  `description: false` leaves out the line.
- **`card`** keeps its title. An empty body becomes three lines, or you can pass
  a block to block out the body yourself.

A skeleton pairs well with a lazy Turbo Frame:

```erb
<%= turbo_frame_tag "stats", src: stats_path, loading: :lazy do %>
  <%= detail_list skeleton: true do |list| %>...<% end %>
<% end %>
```

## Toasts

Mount them once, in the layout:

```erb
<%= flash_toasts %>
```

Then set a flash as usual:

```ruby
redirect_to labels_path, notice: "Label saved."
```

The toast shows in the top-right corner and dismisses itself after five seconds
(`duration:`, in milliseconds). It also has a dismiss button.

- **Holding it open:** hovering or focusing a toast pauses its countdown. Letting
  go resumes it, with at least a second left.
- **Staying put:** the stack is `data-turbo-permanent`, so a toast on screen
  survives a Drive visit or a morph refresh. A flash set before
  `refresh_or_redirect` arrives with the refresh.
- **Tone:** set by `config.flash_tones`. `notice` and `success` are good, `alert`
  and `error` are bad, `warning` is warn, and anything else is info. A bad toast
  interrupts screen readers with `role="alert"`; the rest are announced politely.
- **Filtering:** pass the flashes to show when some aren't meant for the user:
  `flash_toasts flash.to_hash.except("copy_link")`.

To show a toast from a stream response, where there's no redirect to carry a
flash:

```ruby
render turbo_stream: turbo_stream.toast("Invitation sent.")
render turbo_stream: turbo_stream.toast("Couldn't reach Slack.", tone: :bad)
```

The stack sits in the browser's top layer, so a toast shows above an open dialog.
It can't be hovered or dismissed until that dialog closes, because a modal dialog
makes the rest of the page inert, but it still times out on its own.

Needs `import "unmagic/components/toasts"`, which `import "unmagic/components"`
includes. The dismiss button's label is `unmagic.components.toast.dismiss`
("Dismiss").

## Sortable lists and boards

Drag-and-drop ordering, by pointer or keyboard. The server half — ranks, signed
keys and the endpoint — is the
[unmagic-sortable](https://github.com/unreasonable-magic/unmagic-sortable) gem,
which configures these components when it's installed:

```ruby
class Card < ApplicationRecord
  include Unmagic::Sortable
  sortable_within :board_id
  sortable_column :column_id
end
```

### `sortable_list(namespace: nil, params: {}, url: nil, orientation: :vertical, label: nil, **options, &block)`

```erb
<%= sortable_list label: "Interview steps", class: "flex flex-col gap-2" do |list| %>
  <% @steps.ordered.each do |step| %>
    <%= list.item(step) do %>
      <%= sortable_handle label: "Move #{step.name}" %>
      <%= step.name %>
    <% end %>
  <% end %>
<% end %>
```

- **Items:** `list.item(record)` takes its key and rank from
  `config.sortable_item`; `key:` and `rank:` set them directly, and `label:` is
  what a screen reader calls it.
- **Handles:** with a `sortable_handle` in an item, only the handle drags, so the
  rest stays clickable, and the handle is the keyboard stop. Without one, the
  whole item drags once the pointer moves, and the item takes focus.
- **Touch:** a finger lifts an item with a long press, so a swipe still scrolls
  and a tap still taps. A `sortable_handle` grip drags at once.
- **Between lists:** lists sharing a `namespace:` exchange items. A drop posts
  the destination list's `params:`.
- **Keyboard:** Space or Enter picks an item up. The arrows along the list move
  it (`orientation:` decides which) and the arrows across move it to the next
  list. Space drops it; Escape, or tabbing away, puts it back. Each step is
  announced, and Escape also cancels a pointer drag.
- **Scrolling:** a drag near the edge of anything scrollable scrolls it.
- **The drop** fires a cancelable `unmagic-sortable:move` with
  `{ key, original, prev, next, params }`, then PATCHes `url:`
  (`config.sortable_url`) with `moved`, `original`, `prev`, `next` and the params.
  Without a url, the event is all there is.
- **Styling:** `sortable-dragging:`, `sortable-placeholder:`, `sortable-lifted:`,
  `sortable-active:` and `sortable-over:` variants decorate the drag states.

Needs `import "unmagic/components/sortable"`. I18n under
`unmagic.components.sortable`: `handle`, `instructions`, `picked`, `moved`,
`dropped` and `cancelled`, with `{item}`, `{list}`, `{position}` and `{count}`.

### `board(id:, url: nil, columns_url: nil, sortable_columns: true, label: nil, column_height: nil, **options, &block)`

```erb
<%= board id: "roadmap" do |board| %>
  <% @columns.each do |column| %>
    <% board.column column, title: column.name, params: { column_id: column.id } do |col| %>
      <% col.actions { menu { |m| m.link "Rename", edit_column_path(column) } } %>
      <% column.cards.ordered.each { |card| col.card(card) { render card } } %>
      <% col.add url: cards_path, field: "card[title]", params: { "card[column_id]" => column.id } %>
    <% end %>
  <% end %>
  <% board.add_column url: columns_path, field: "column[name]" %>
<% end %>
```

- **Moving:** cards move within and between the board's columns, posting the
  column's `params:`. Columns move along the board by their header, and the grip
  in it is their keyboard stop. On a phone, press and hold a card or a header. `sortable_columns: false` fixes them in place.
- **Forms:** `col.add` and `board.add_column` open into a one-field form. Enter
  submits it, Escape closes it, and it stays open after adding, so several can be
  added in a row.
- **Size:** `column_height:` (default `75dvh`) is how tall a column grows before
  its cards scroll.
- **Where drops go:** `url:` is where they post; `columns_url:` sends column drops
  elsewhere.

Needs `import "unmagic/components/sortable"` and `"unmagic/components/board"`.
I18n under `unmagic.components.board`: `label`, `add_card`, `add_card_submit`,
`add_column`, `add_column_submit`, `cancel`, `move_column` and `cards`.

## Avatars

### `avatar(name, src: nil, size: :medium, shape: :circle, tint: true, skeleton: false, **options)`

```erb
<%= avatar "Ada Lovelace" %>
<%= avatar @user.name, src: @user.avatar_url, size: :large %>
<%= avatar "Acme Ltd", shape: :square %>

<%= avatar_group max: 3, size: :small do |group| %>
  <% @members.each { |member| group.avatar member.name, src: member.avatar_url } %>
<% end %>
```

- **Initials** come from the first and last words ("Ada Lovelace" is "AL") and
  always render. The image sits on top of them, so a broken image shows the
  initials without any script.
- **Tint:** the initials sit on one of six palette tints picked from the name
  with `unmagic-color`'s stable string hash, so a person keeps their colour on
  every page and every server. `tint: false` is neutral. Override
  `UnmagicAvatar--tint-1` … `-6` to recolour them.
- **Sizes:** `:small`, `:medium` and `:large` (1.5, 2 and 2.5rem).
  `skeleton: true` renders a skeleton circle of the same size.
- **Accessibility:** an avatar is `role="img"` named for the person. Pass
  `"aria-hidden": true` when the name is written beside it.
- **Groups:** `avatar_group` sets the size and shape for every avatar in it, and
  collapses past `max:` into a "+N" whose title names the rest.

I18n: `unmagic.components.avatar.group` ("%{count} people") and
`unmagic.components.avatar.more` ("+%{count}").

## Elapsed times

### `elapsed_tag(time, direction: :up, **options)`

```erb
<%= elapsed_tag tool_call.started_at %>                    <%# 3m 5s, and counting %>
<%= elapsed_tag session.expires_at, direction: :down %>    <%# 42s, and falling %>
```

A clock that counts up from a moment the server named, a second at a time, or
down to one, stopping at zero and firing `unmagic-elapsed:end`. Work that takes a
minute and work that has hung look the same behind a spinner; a number that keeps
moving is the difference.

The server renders the current reading, so it is right before the script loads.
Readings are whole seconds — `2s`, `3m 5s`, `1h 4m 2s` — and a settled duration
under a second is milliseconds (`640ms`). The words are the
`unmagic.components.elapsed.*` keys (`milliseconds`, `seconds`, `minutes`,
`hours`); the element writes the English forms as it ticks. A blank time renders
an em dash. Needs `import "unmagic/components/elapsed"`.

## AI chat

Components for rendering an agent's work, in the spirit of
[assistant-ui](https://www.assistant-ui.com) but server-rendered: the host renders
each turn, Turbo Streams keep it live, and small custom elements pace the reveal.

```erb
<%= turbo_stream_from @chat %>

<div id="transcript" class="h-[70dvh] overflow-y-auto">
  <%= ai_chat id: "entries", scroller: "#transcript" do |chat| %>
    <% chat.welcome do %>
      <%= ai_chat_welcome heading: "What can I help with?" do |welcome| %>
        <% welcome.suggestion "Who hasn't replied yet?" %>
      <% end %>
    <% end %>
    <%= render @chat.entries %>
  <% end %>
</div>

<%= form_with model: Message.new, url: chat_messages_path(@chat), id: "composer" do |form| %>
  <%= ai_chat_composer form: form, field: :content, state: @chat.run_state do |composer| %>
    <% composer.optimistic id: "message[client_id]", container: "#entries" %>
  <% end %>
<% end %>
<%= ai_chat_stop_form chat_stop_path(@chat) %>
```

```erb
<%# app/views/messages/_message.html.erb %>
<%= ai_chat_message role: message.role.to_sym, id: dom_id(message), streaming: message.pending? do %>
  <%= message.user? ? message.content : Markdown.render(message.content) %>
<% end %>
```

They need Turbo and `import "unmagic/components"`, or the modules named below.

### How the pieces fit

- **Entries are upserted by id.** Broadcast each entry with the gem's `upsert`
  action into the transcript's id. A record already on the page is replaced in
  place; a new one is inserted in id order.

  ```ruby
  broadcast_action_to chat, action: :upsert, target: "entries", partial: "messages/message", locals: { message: self }
  ```

- **The question is drawn before the server has it.** `composer.optimistic`
  renders an `<unmagic-uuid-input>` and a template of the question. On submit,
  `<unmagic-optimistic>` draws the question, dimmed, under the minted id. Create
  the record under that id (`message[client_id]`) and its broadcast replaces the
  placeholder.
- **Replies stream as whole renders.** While a reply is being written, send the
  whole of it so far, rendered, to the body's id. `<unmagic-streaming-markdown>`
  works out what's new and reveals it at the model's own average pace, so bursts
  read as one stream. When the turn settles, upsert the whole message. The new
  element picks up the reveal where the old one left off.

  ```ruby
  broadcast_action_to chat, action: :stream_markdown, target: "#{dom_id(self)}_content",
    html: Markdown.render(content)
  ```

- **The gem never parses Markdown.** Hand it your own rendered, sanitised HTML.
  `UnmagicProse` styles it, and code blocks, like tool payloads, go through
  `config.code_block`.
- **Only the composer's button changes with the turn's state.** Redraw it with
  `ai_chat_composer_action` so a half-typed draft survives.
- **Amber means waiting on a person.** A question, a permission request or a plan
  step parked on someone is the one state that won't move on its own, so it is
  the one in colour.

### `ai_chat(id:, scroller: nil, follow: true, scroll_to_latest: true, **options, &block)`

The scrolling region turns are rendered into: a polite `role="log"`. It renders
no entries of its own; use a partial per entry type.

- **Following:** it keeps the scroller (the page, or `scroller:`) at the bottom
  while the reader is there, and stops when they scroll up. A jump-to-latest
  button shows meanwhile (`scroll_to_latest: false` for none). `follow: false`
  renders a bare log.
- **Spacing:** turns are separated by a gap that hidden entries don't earn. Mark
  hidden entries between two tool calls (a tool result's anchor) with
  `data-ai-chat-timeline="gap"` so the run stays joined.
- **Welcome:** `chat.welcome` shows while there are no entries, and hides as the
  first one arrives.

Needs `import "unmagic/components/autoscroll"`. I18n:
`unmagic.components.ai_chat.transcript.label` ("Conversation") and `.latest`
("Jump to latest"). The button's dock is sticky at `bottom-4`; lift it with
`.UnmagicAIChat__latest { bottom: … }` if a sticky composer covers it.

### `ai_chat_message(content = nil, role:, id: nil, streaming: false, final: false, optimistic: nil, **options, &block)`

One turn. A user's turn is a bubble of plain text with its line breaks kept; an
assistant's is unbubbled prose.

- **The body** of an assistant turn with an id is an
  `<unmagic-streaming-markdown id="#{id}_content">`. `streaming: true` shows a
  thinking spinner until the first flush and marks the body busy. `final: true`
  refuses any later flush, for a stopped or failed reply.
- **Empty:** a settled assistant turn with nothing in it is `hidden`, keeping its
  id for broadcasts.
- **Parts:** `turn.reasoning(**options) { }` (see `ai_chat_reasoning`),
  `turn.actions { }`, `turn.branches { }` and `turn.attachments { }` (above a
  user's bubble).
- **Optimistic:** `optimistic: { id:, text: }` renders the template a composer
  fills from those fields, dimmed.

I18n: `unmagic.components.ai_chat.message.user` ("You said"), `.assistant`
("Assistant said") and `.thinking` ("Thinking"), for screen readers.

### `streaming_markdown_tag(content = nil, id:, final: false, streaming: false, **options, &block)`

The streaming body on its own. Send flushes with
`turbo_stream.stream_markdown(target, html)`, each carrying the whole render so
far. Under reduced motion each flush paints at once. It fires
`unmagic-streaming-markdown:settle` when it has caught up. Needs
`import "unmagic/components/streaming_markdown"`.

### `ai_chat_reasoning(content = nil, title: nil, streaming: false, duration: nil, open: false, **options, &block)`

The model's thinking, collapsed above its reply. `duration:` titles it "Thought
for 12s"; `streaming: true` shows "Thinking…". `reasoning.block { }` adds a
block. Blank content renders nothing. I18n:
`unmagic.components.ai_chat.reasoning.title`, `.thinking` and `.duration`.

### `ai_chat_tool_call(name:, state:, id: nil, icon: nil, open: false, timeline: true, **options, &block)`

```erb
<%= ai_chat_tool_call name: call.name, state: call.state, id: dom_id(call), icon: call.category_icon do |tool| %>
  <% tool.summary call.summary %>
  <% tool.timing started_at: call.started_at, duration: call.duration %>
  <% tool.asked call.arguments %>
  <% tool.answered call.response %>
<% end %>
```

- **State:** `:queued`, `:running`, `:waiting`, `:done` or `:failed`. A running
  call is busy, spins, and counts up with `elapsed_tag`. A done call shows
  `icon:`, what it was about, in place of a column of identical ticks.
- **Timeline:** consecutive calls are joined by a line, which runs down an open
  call's body. `timeline: false` leaves a call out of the run.
- **Parts:** `summary`, `timing`, `asked` and `answered` (payloads, in a
  `<details>`, so no script and no state to restore after a redraw), `failures`
  (a count for a batch that mostly worked), `progress` (a line with id
  `"#{id}_progress"` to replace as the tool reports), and `made { }` (output
  kept outside the fold).

I18n under `unmagic.components.ai_chat.tool_call`: `queued`, `running`,
`waiting`, `done`, `failed`, `asked`, `answered`, `failures`, `partly_failed`,
`running_for` and `took`.

### `ai_chat_payload(payload, label: nil, language: nil, duration: nil, copy: false, **options)`

What went into a tool call or came back. A Hash, an Array, or a string holding
JSON is laid out a key to a line as `:json`; anything else is `:plaintext`
unless `language:` says otherwise. It renders through `config.code_block`,
scrolls past a height, wraps long lines, and is reachable by keyboard. `copy:
true` adds a copy button. `nil` renders nothing. I18n:
`unmagic.components.ai_chat.payload.took` and `.label` ("Payload").

### `ai_chat_composer(form:, field:, state: :idle, label: nil, stop_form: "stop_turn", placeholder: nil, rows: 2, **options, &block)`

- **The form needs an `id:`.** Send names it with `form=`, and Stop names
  `stop_form:`. Render `ai_chat_stop_form(url)` outside your form, since forms
  can't nest.
- **State** — `:idle`, `:running`, `:stopping` or `:waiting` — changes only the
  button region (id `"#{form_id}_action"`, a polite live region). The field is
  never disabled. Redraw the region alone with
  `ai_chat_composer_action(form:, state:)`.
- **Keys:** Enter sends and Shift+Enter makes a new line. Enter does nothing
  while there's no Send button. A successful submit resets the form and keeps
  focus in the field.
- **Parts:** `composer.optimistic(id:, container:)`, `composer.attach { }`,
  `composer.actions { }` and `composer.menu { }` (an `ai_chat_slash_menu`).
- **The field** is the composer's own chrome, not a `control_class` control: the
  box around it is the control and takes the focus ring.

Needs `import "unmagic/components/ai_chat"`. I18n under
`unmagic.components.ai_chat.composer`: `send`, `stop`, `stopping`, `waiting`
and `label`.

### `ai_chat_slash_menu(for: nil, id: nil, trigger: "/", above: false, insert: nil, **options, &block)`

Commands offered on a slash. `menu.item(name, description:, arguments:)` for
each; every item is rendered and typing filters them by prefix. Up and Down move,
Enter or Tab takes one, Escape closes, and focus stays in the field (the combobox
pattern). Picking writes `"/name "` at the cursor. `for:` defaults to the
composer's field. Needs `import "unmagic/components/slash_menu"`. I18n:
`unmagic.components.ai_chat.slash_menu.label` ("Commands").

### `ai_chat_attachments(align: :start, **options, &block)` and `ai_chat_dropzone(input:, url: nil, field: nil, chips: nil, label: nil, **options, &block)`

`ai_chat_attachments` lists the files a sent turn carries
(`files.file name, size:, url:, thumbnail:`; `align: :end` for a user's turn).

`ai_chat_dropzone` wraps a region that takes dropped and pasted files, with an
overlay while dragging. `input:` is the file input the files join, which is also
the way in for anyone who can't drag. Without `url:`, files wait on that input
and post with the form. With `url:`, each file is POSTed on the spot as `file`,
and the JSON response's `value` is posted with the message under `field:`.
`chips:` is where attached files are listed: the composer's
`[data-ai-chat-chips]`. It fires `unmagic-dropzone:attach` and `:error`. Needs
`import "unmagic/components/dropzone"`. I18n under
`unmagic.components.ai_chat.attachments`: `drop`, `attached`, `remove` and
`failed`.

### `ai_chat_welcome(heading:, heading_tag: :h2, composer: "composer", field: nil, **options, &block)`

What an empty conversation says. `welcome.body(text)` and
`welcome.suggestion(label, icon:, fill:, value:)`. Pressing a suggestion puts it
in the composer form with id `composer:` and sends it, unless `fill: true` or a
turn is running. Needs `import "unmagic/components/ai_chat"`.

### `ai_chat_request(state:, url: nil, method: :patch, prompt: nil, label: nil, scope: :response, live: false, **options, &block)`

```erb
<%= ai_chat_request state: :waiting, url: answer_path(@chat), live: true do |request| %>
  <% request.question "How should it sound?", header: "Tone" do |q| %>
    <% q.option "Friendly", description: "A short, warm check-in" %>
    <% q.option "Direct" %>
  <% end %>
<% end %>
```

- **Ask with questions** (`multiple: true` for checkboxes; answers post as
  `answers[i][]`) **or with a form** (`request.form { |form| … }`), not both.
  `request.decline` adds a Decline that skips validation.
- **Answered states** — `:accepted`, `:declined`, `:cancelled`, `:timed_out` —
  keep the questions and show what was picked (`question picked:`) or answered
  (`request.answer label, value`). Declined and dropped cards dim.
- **`live: true`** adds `role="alert"` and, if nothing else has focus, focuses
  the first option.

I18n under `unmagic.components.ai_chat.request`: `waiting`, `asked`, `answer`,
`decline`, `accepted`, `declined`, `cancelled`, `timed_out` and `unanswered`.

### `ai_chat_permission(tool:, state:, url: nil, live: false, outcome: nil, **options, &block)`

```erb
<%= ai_chat_permission tool: "delete_files", state: :waiting, url: permission_path(@call) do |ask| %>
  <% ask.argument "paths", "drafts/*" %>
  <% ask.summary { markdown(@call.summary) } %>
  <% ask.allow confirm: "Delete these files? This can't be undone." %>
  <% ask.allow "Allow for any chat", params: { widened: true } %>
  <% ask.refuse %>
<% end %>
```

- **The ask** — the tool's own name and its arguments — comes before the
  reasoning, because it's what the decision is about.
- **Actions:** the first `allow` is the prominent, red, consequential choice; a
  later one is the wider grant. Offer that only when there is something to
  widen. `allow` POSTs and `refuse` DELETEs to `url:`, each with `params:` and
  `confirm:`.
- **Focus** goes to the card when it arrives, never to Allow.
- **Answered:** `:granted`, `:refused`, or `:lapsed` (answered in the chat,
  nothing granted), with `outcome:` to reword the sentence.

I18n under `unmagic.components.ai_chat.permission`: `waiting`, `asked`, `allow`,
`refuse`, `granted`, `refused` and `lapsed`.

### `ai_chat_proposal(state: :pending, icon: :lightbulb, id: nil, **options, &block)`

An offer the agent made in passing, which doesn't stop the work: `offer.claim`,
`offer.meta`, `offer.accept { }` and `offer.reject { }` while `:pending`; the
outcome (`"Saved"`, `"Dismissed"`, or `offer.outcome`) once `:accepted` or
`:rejected`. It is an `<aside>` named by its claim, and `not-prose` so it can sit
inside a reply. I18n: `unmagic.components.ai_chat.proposal.accepted` and
`.rejected`.

### `ai_chat_citation(compact: false, **options, &block)`

A quotation rendered from the record, not the model's paraphrase:
`cite.avatar` (with no block, the gem's avatar for `who`), `cite.who`,
`cite.when(time, url:)` and `cite.quote(text)`. The quote is escaped text with
its line breaks kept. `compact: true` is one line, for a list of sources.

### `ai_chat_failure(message = nil, live: false, **options, &block)`

A turn that fell over. The sentence is for whoever asked. `failure.cause` sits
above the fold; `failure.detail(label, payload, language:)` rows fold away for
whoever works on the assistant; `failure.retry { }` holds your control. Render
it below a turn's body, never in its place. `live: true` adds `role="alert"`.
I18n: `unmagic.components.ai_chat.failure.details`.

### `ai_chat_plan(**options, &block)` and `ai_chat_workspace(**options, &block)`

Two sections of one side panel. Both are collapsible, open by default, and
always render, empty or not, so a broadcast has something to replace.

- **`plan.step(title, state:)`:** `:pending`, `:in_progress`, `:waiting` or
  `:completed`, with an optional block for detail. The count reads
  completed/total, or `completed:`/`total:` when a panel shows only some steps.
- **`workspace.file(path, size:, url:, icon:)`:** the workspace folds the
  paths into a `tree_view` of folders, open, with folders ahead of the files
  beside them. A folder that holds only one folder joins it in a single row,
  which shortens from the front so the last folder's name stays. A file with a
  url is a link, and its glyph comes from its extension (`:file_code`,
  `:file_text`, `:file_image`, `:file_json`, `:file_spreadsheet`,
  `:file_archive`, `:file_audio`, `:file_video`, else `:file`) unless `icon:`
  says otherwise. Each row's title is its full path; the count is the number of
  files.
- **Both take** `title:`, `open:`, `empty:`, `collapsible:` and `title_tag:`
  (`:h2`). The workspace also takes `count:`.

I18n under `unmagic.components.ai_chat`: `plan.title`, `plan.empty`,
`plan.pending`, `plan.in_progress`, `plan.waiting`, `plan.completed`,
`workspace.title` and `workspace.empty`.

### `ai_chat_action_bar(for:, reveal: :hover, **options, &block)` and `ai_chat_branch_picker(index:, count:, previous: nil, next: nil, method: :get, **options)`

The controls under a turn. `bar.copy(text)`, `bar.action(label, url, icon:,
method:, confirm:)` and `bar.control { }` make a toolbar with one Tab stop and
arrow keys between controls (`<unmagic-toolbar>`). `reveal: :hover` shows it on
hover or focus, and always on touch screens; it is never hidden from the
keyboard.

`ai_chat_branch_picker` walks between versions of a turn: "Version 2 of 3",
with a disabled end where there's nowhere to go. What a branch is stays your
application's business, and one version renders nothing.

Needs `import "unmagic/components/toolbar"` and `"unmagic/components/ai_chat"`.
I18n: `unmagic.components.ai_chat.action_bar.label` and
`unmagic.components.ai_chat.branch_picker.label`, `.previous` and `.next`.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome at
https://github.com/unreasonable-magic/unmagic-components.

## License

Available as open source under the terms of the [MIT License](LICENSE).
