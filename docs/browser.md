# `Unmagic::Components::Browser`

> Status: built
> Relates to: the old preview app (`config.ru`, `preview/`), which this
> replaces; `Unmagic::Icon::Web`, which it follows

## Purpose

A component browser that a host app mounts, so anyone using the gem can look
through every component, its examples and their source inside their own app,
without cloning this repo:

```ruby
# config/routes.rb
mount Unmagic::Components::Browser::Engine => "/unmagic/components" if Rails.env.development?
```

The preview used to run only from a checkout, because the gemspec leaves out
`preview/` and `config.ru`. The browser moves it into the gem. The repo's
`config.ru` is now a one-file host that mounts it, so `bin/dev` runs the same
code every host gets.

It is **not** a way to theme or configure components, and it doesn't show the
host's Tailwind theme. It ships its own stylesheet, so it looks the same in
every app (see Styling).

## API

- **The mount is the whole setup.** There's nothing to configure and no host
  CSS or JS to change.
- **It needs `turbo-rails`,** because the dialog, toast, board and AI chat
  examples need Turbo. Without it, the first request raises an error that
  names turbo-rails. It can't check at boot, because a host that eager loads
  the browser without mounting it may not have Turbo at all.
- **The engine is `Browser::Engine`, not `Browser`.** Rails finds an isolated
  engine's route helpers through its namespace, and an engine class can't be
  its own namespace.
- **Where to mount it, and who sees it, is the host's decision,** as it is for
  `Unmagic::Icon::Web`. The README shows a development-only mount and an
  `authenticate` block.
- **It has these pages:**
  - overview
  - installation
  - theming
  - a Blocks gallery, one page per block, and isolated full-page previews
  - one page per component
  - the light/dark switch (`?theme=`, kept in the session)

  The old one-page-per-group URLs redirect with a relative path, so they keep
  the mount prefix.

## Shape

A second, isolated engine in the gem. Its root is
`lib/unmagic/components/browser/`, not the gem root: the main engine's root is
the gem root, so anything under the top-level `app/` would be autoloaded into
every host.

```
lib/unmagic/components/browser.rb      Browser (module), Browser::Engine, Browser.asset_roots
lib/unmagic/components/browser/
  config/routes.rb                     pages, demo endpoints, asset mounts
  app/controllers/…/browser/
    application_controller.rb          theme, catalog, turbo check, prefixed session keys
    pages_controller.rb                overview, installation, theming, component
    demos_controller.rb                dialog, toast, board and AI chat endpoints
  app/helpers/…/browser/application_helper.rb   importmap, asset paths, example source
  app/models/…/browser/                Catalog, Thing, Profile, Pager, Reply, BoardStore
  app/views/layouts/…/browser/application.html.erb
  app/views/…/browser/application/     nav, crumb, example, code partials
  app/views/…/browser/pages/, demos/
  app/views/…/browser/examples/<slug>/_<key>.html.erb
  catalog/<slug>.rb                    one component's description and examples
  tailwind/browser.css                 source for the prebuilt stylesheet
  assets/browser.css                   the prebuilt stylesheet (committed)
```

- **Controllers inherit `ActionController::Base`,** not the host's
  `ApplicationController`, so the host's auth, layout and callbacks stay out.
  The host's session, flash and CSRF settings still apply.
- **It ignores the host's configuration.** Every action runs inside
  `Unmagic::Components.with_default_configuration`, so the examples render
  through the built-in seams. A host's `empty_state` or `pagination` renders
  the host's partials, which call the host's helpers, and a controller that
  inherits `ActionController::Base` doesn't have them. The override is kept in
  `ActiveSupport::IsolatedExecutionState`, so the host's own requests running
  at the same time keep the host's seams.
- **Everything in the session is prefixed.** Keys are
  `unmagic_components_browser_*` (the theme, the dialog's profile, the board,
  the AI chat reply), so none collides with a host's `:theme`.
- **Examples use the engine's route helpers** (`profile_dialog_path`,
  `component_path("toast")`), so links and forms keep the mount prefix. The
  Code tab shows those helpers.
- **The catalog reloads on every request in development** and loads once
  otherwise.
- **The table examples pass their stand-in pager** (`paginate: @pager`),
  because the default `pagy_for` only finds a pager the action assigned to
  `@pagy`.
- **`activemodel` is required by the two fixtures that use it,** not by the
  gemspec.
- **Example sections are named `<slug>_<key>`.** A bare key collided with ids
  the layout uses: the dialog's `modal` example shadowed the shared modal's
  `#modal` frame, which sent modal links to a full page.

## Styling

- **The stylesheet is prebuilt.** `tailwind/browser.css` imports `engine.css`,
  scans only the browser's `app/` and `catalog/`, and keys the dark variant to
  `[data-theme=dark]`.
- **`rake browser:css` writes the minified build** to `assets/browser.css`.
  `bin/dev` reruns it when anything changes, and `rake build` depends on it.
- **The build is committed,** so a `github:` install works. A spec rebuilds it
  and fails when the committed file is stale; the lockfile pins
  `tailwindcss-ruby`, so the output is deterministic.
- **It shows the gem's default look,** in both its stylesheet and its seams, so
  nothing a host configured goes unstyled. The host's I18n still applies.

## JavaScript and static files

The browser depends on neither the host's asset pipeline nor importmap-rails.

- **`Rack::Files` apps mounted in the engine's routes serve the assets.** Under
  `<mount>/assets/<kind>/` it serves:
  - `stylesheets`: `browser.css`
  - `javascripts`: the gem's `app/assets/javascripts`
  - `turbo`: turbo-rails' `app/assets/javascripts`

  URLs carry `?v=<gem version>-<file mtime>`, and responses are cached as
  immutable. The version matters: gem packaging gives every file the same
  mtime.
  `Rack::Files` refuses paths outside its root.
- **The layout writes its own importmap.** It maps the names
  `config/importmap.rb` pins (`unmagic/components`,
  `unmagic/components/<name>`) and `@hotwired/turbo-rails` to those URLs, then
  imports `unmagic/components`. Both scripts carry the host's CSP nonce, if it
  has one.
- **Examples with inline scripts don't carry a nonce.** Under a strict CSP
  without `unsafe-inline`, the streaming Markdown, sortable handles and AI chat
  demos won't play.

## Specs

`spec/unmagic/components/browser_spec.rb`, against the spec app, which mounts
the engine at `/unmagic/components`. It checks that:

- the overview, installation and theming pages, and every catalog page,
  answer 200.
- no component page repeats an id outside a `<template>`.
- links, form actions, a demo's redirect and an old-URL redirect keep the
  prefix.
- the stylesheet, a component module and Turbo are served with the right
  types, and nothing outside the asset roots is.
- the importmap covers exactly what `config/importmap.rb` pins, plus Turbo.
- the committed `browser.css` matches a fresh build.
- a missing turbo-rails raises the documented error.
- no seam a host configured runs on any page.

## Checked by hand

In Chrome, mounted at `/unmagic/components` (every page also renders when
mounted at `/`):

- the modal: open, a 422, a save that closes it with a toast
- flash and streamed toasts
- the AI chat composer's streamed reply
- adding a board card
- the dark theme

Not checked in this pass:

- dragging on the board
- keyboard walkthroughs
- reduced motion

Examples may provide a matching `_key.turbo_stream.erb` beside `_key.html.erb`.
The Code tab includes both the trigger and the actual response source.


## Blocks and global navigation

The full-width global header switches between Components and Blocks. Add future
destinations to `ApplicationHelper#browser_sections`; the sidebar and mobile
menu belong to the selected section.

`BlockCatalog` lists composed pages separately from component primitives. Each
entry names its category and component dependencies. Add a self-contained ERB
partial under `app/views/unmagic/components/browser/blocks/_<slug>.html.erb`,
with sample data defined in the partial so the displayed source can be copied.
The detail page renders that exact file as source, links its component
dependencies, and embeds the isolated `/blocks/:slug/preview` page. Preview
frames load the browser stylesheet, JavaScript and remembered theme.

The gallery, detail pages and previews are included in static exports. Blocks
currently use local sample data and require no demo endpoints.

The preview toolbar offers Desktop (available width), Tablet (768px), and
Phone (390px) viewports, plus independent Light/Dark buttons, reload, and open.
Fixed widths scroll horizontally when the browser itself is narrower.
`preview_theme` overrides only the preview and never changes the saved global
theme. Browser-only controls live in `assets/browser.js`, also exported.

Authentication blocks use native validation and preview-only forms that never
submit credentials. Replace the form method and action with your application's
authentication endpoint when adopting the source.

### Page families

The gallery groups blocks by category, with individual blocks linked in the
sidebar. Dashboard examples cover a workspace, audience analytics and sales.
Settings cover profiles, billing and notifications. Authentication includes
login, signup and password recovery; shared pages include a 404 layout.

The settings and recovery forms use the same local preview handler as the
authentication examples. A form can supply `data-block-demo-message` for its
specific feedback. Reset clears both native fields and the feedback message.
Forms do not persist or transmit changes.

Page-type references: [Untitled UI settings pages](https://www.untitledui.com/react/components/settings-pages)
and [dashboards](https://www.untitledui.com/react/components/dashboards).
These blocks use original ERB compositions of this library's components.


### Component coverage

Every catalog component is used by at least one block. The gallery shows the
coverage count, and component pages link back to their blocks. Declare the
components a block actually uses in `BlockCatalog`; the browser specs reject
unknown component names and new components with no block.

The project planner demonstrates local drag ordering and a command palette;
the asset studio includes crop, zoom and color sampling; the release monitor
combines build logs and rollout states; the customer workspace demonstrates
dialogs, confirmation, toast feedback and working local pagination. Two AI
workspaces cover conversation/composer and review/diagnostic components.
Copyable snippets include their local interaction scripts when needed.
