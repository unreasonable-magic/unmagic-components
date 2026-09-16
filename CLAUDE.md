# unmagic-components

Server-rendered UI components for Rails views: plain Ruby classes behind
ActionView helpers, one Tailwind CSS v4 source file the host's Tailwind build
compiles, and self-registering custom elements. Tailwind v4 is required, and
there is no Stimulus.

## Building or changing a component

1. Read [`docs/design-principles.md`](docs/design-principles.md). It covers how
   the Ruby, CSS, JavaScript, accessibility, specs, browser pages and docs are done
   here.
2. Write the component's design note first. Copy
   [`docs/components/_template.md`](docs/components/_template.md) to
   `docs/components/<name>.md`, or refresh the existing note. Get it reviewed
   before writing code.
3. Build it to the note, then follow the checklist at the end of the
   principles.

Component ideas can come from other libraries, such as Rails Blocks, but only
as a list of what's missing. Never copy their markup, classes or code: design
each component from scratch to these principles.

## Layout

- `lib/unmagic/components/`: component classes, `action_view_helpers.rb`,
  `form_builder.rb`, `configuration.rb`
- `app/assets/tailwind/unmagic_components/engine.css`: every component's
  styles, as Tailwind component CSS (`@apply`, palette colours with `dark:`)
- `app/assets/javascripts/unmagic/components/`: one custom element per file,
  imported by `components.js`
- `spec/unmagic/components/`: RSpec and Nokogiri specs (`build_view`, `html`)
- `lib/unmagic/components/browser/`: the component browser engine a host mounts
  (catalog, example partials, prebuilt `assets/browser.css`)
- `config.ru`: a host app that mounts the browser, for `bin/dev`

## Commands

```sh
bundle exec rspec      # specs
bundle exec rubocop    # lint
bin/dev                # builds the browser's CSS, then serves the browser at http://localhost:5701 (?theme=dark for dark)
bundle exec rake browser:css  # rebuilds lib/unmagic/components/browser/assets/browser.css (commit it)
```
