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

The engine mixes the helpers into ActionView automatically — no initializer
needed to get started. The interactive components need their JavaScript too; with
importmap-rails the engine pins it for you, so add `import "unmagic/components"`
to your application.js (see [Dialogs](#dialogs)).

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

Three seams, each with a working default. Point them at your own versions if you
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

`button_classes(variant = :default, size: nil)` returns the class string, so the
look works with `link_to`, `button_to` and `form.submit` alike. The variants are
`:default`, `:primary`, `:ghost`, `:danger` and `:icon`; the sizes are `:small`
and `:large`.

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

### `empty_state(content = nil, **options, &block)`

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

## Menus, tabs and copy buttons

### `menu(label = nil, align: :end, **options, &block)`

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
