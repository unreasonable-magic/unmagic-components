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
- **Everything in the session is prefixed.** Keys are
  `unmagic_components_browser_*` (the theme, the dialog's profile, the board,
  the AI chat reply), so none collides with a host's `:theme`.
- **Examples use the engine's route helpers** (`profile_dialog_path`,
  `component_path("toast")`), so links and forms keep the mount prefix. The
  Code tab shows those helpers.
- **The catalog reloads on every request in development** and loads once
  otherwise.
- **The table examples pass their stand-in pager** (`paginate: @pager`)
  instead of relying on a global `pagy_for`, which stays the host's.
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
- **It shows the gem's default look.** The examples still render through the
  host's configuration and I18n, so a host whose `control_class` returns its
  own classes sees unstyled form examples. The README says so.

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
