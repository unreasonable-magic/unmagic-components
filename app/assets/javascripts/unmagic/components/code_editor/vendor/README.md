# Vendored editor dependencies

Copied from Proj's GraphQL console. Each file's header records its package version
and original source. Bare dependency imports are rewritten to
`unmagic/components/code_editor/vendor/<filename-without-js>` to isolate these
versions from the host application's packages. `LICENSES.txt` contains upstream
notices, including the language-service bundle's transitive dependencies.

CodeMirror, cm6-graphql and dependencies use JSPM ESM distributions. GraphQL
16.11.0 and graphql-language-service 5.7.0 use esm.sh browser bundles:

- https://esm.sh/graphql@16.11.0/es2022/graphql.bundle.mjs
- https://esm.sh/graphql-language-service@5.7.0/es2022/graphql-language-service.bundle.mjs?external=graphql

GraphQL is external in the language-service bundle so schema objects use the same
GraphQL instance. GraphQL's process import uses the vendored browser shim.

Keep this subtree pinned with preload:false. Keep language imports dynamic in
editor.js and keep editor.js out of the shared entry point. After updating,
run bin/demo-code-editor: Ruby specs cannot catch missing browser imports.

The ten additional languages are generated from pinned npm packages by
`bin/support/code-editor-languages/build.mjs`. To regenerate, run `npm ci
--ignore-scripts` and `node build.mjs` in that directory. The package lock fixes
all build inputs; the host app never needs npm. The language parsers are bundled
with shared CodeMirror and Lezer runtime imports left external and namespaced.
HTML bundles its JavaScript/CSS parsers; TypeScript reuses the JavaScript module.
Ruby vendors only the Ruby mode from legacy-modes. `LICENSES-languages.txt`
contains all included package notices.
