# Code editor

## Purpose and API

Backport Proj's CodeMirror 6 editing into a reusable native textarea enhancement.
`code_editor_tag(name, value = nil, language: :plaintext, schema: nil, **options)`
and `form.code_editor(method, options = {})`, also usable with `field as: :code_editor`.
Languages are plaintext, json, graphql, javascript, typescript, python, ruby,
html, css, sql, java, cpp and go; schema is optional GraphQL SDL. Other
options, including id, class, aria, required, disabled and readonly, go on the
textarea so Rails labels, errors and form submission keep working. Blank is empty.

## Markup and accessibility

`unmagic-code-editor.UnmagicCodeEditor` contains the escaped native textarea,
an initially empty editor mount and a polite status. The textarea works without
JS and during loading or failure. CodeMirror inherits labels, descriptions and
invalid state. Tab leaves the editor. Native invalid events focus the editor.
The element exposes value/focus/editor and bubbles ready, change and error events.

## Loading

Only the small custom element registration is in the common entry point. On
connection it dynamically imports the editor runtime; that runtime imports the
vendored CodeMirror core and only the selected language. Every runtime/vendor
pin has preload:false and a gem-specific namespace to avoid host version conflicts.
No CDN requests, npm install or host build step. Static browser exports include
these assets without eager script tags. The gallery thumbnail is a textarea only.

## Behaviour and Turbo

Synchronize the textarea on every edit for FormData and input/change listeners;
respect form reset and programmatic value changes. Keep defaultValue separate
from drafts. Destroy on disconnect and before-cache; preserve drafts in an
attribute for cloned snapshots, ignore stale asynchronous loads, and rebuild on
Turbo render/morph. Content streamed in upgrades through custom elements.
Destroy the view before morphing the wrapper, then rebuild from the server markup.

## Styling and small screens

Tailwind neutral palette and host dark variant. Wrap long lines and constrain
width; editor scrolls vertically. Highlight tokens use Tailwind palette pairs.
No animations. Readonly/disabled semantics come from the textarea.

## Verification and preview

RSpec checks escaping, options, form integration, language validation and preload
policy. A replayable visible browser demo checks no heavy requests without an
editor, JSON without GraphQL requests, schema completion, form/reset, failure
fallback and Turbo restoration, light/dark desktop/phone. Browser catalog has
JSON, GraphQL and readonly examples. Review: API follows existing textarea
wrappers; scoped pins preserve the shared entry point's existing behavior.

## Language expansion

Add JavaScript, TypeScript, Python, Ruby, HTML, CSS, SQL, Java, C++ and Go.
Each language is dynamically imported; TypeScript shares the JavaScript parser.
HTML includes its embedded JavaScript/CSS parsers. Ruby uses CodeMirror’s stream
parser. Vendor reproducible language bundles with shared CodeMirror/Lezer core
external, so no second EditorState instance is introduced. Extend the demo to
verify each language highlights and never fetches unrelated language bundles.
