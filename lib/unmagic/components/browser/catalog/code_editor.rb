# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :code_editor,
  name: "Code editor", group: "Forms", helper: "code_editor_tag",
  import: "unmagic/components/code_editor",
  description: "CodeMirror editing over a native textarea. Editor code loads only when an editor appears; Language support loads only when selected.",
  examples: [
    { key: :languages, title: "Ten common languages", layout: :full, description: "JavaScript, TypeScript, Python, Ruby, HTML, CSS, SQL, Java, C++ and Go. This example loads all ten because it renders an editor for each." },
    { key: :json, title: "JSON form field", layout: :full, description: "Edits submit through the textarea; Reset restores the initial value." },
    { key: :graphql, title: "Schema-aware GraphQL", layout: :full, description: "Pass GraphQL SDL for completion and diagnostics. Ctrl-Space opens completions." },
    { key: :readonly, title: "Read-only results", layout: :full, description: "Selectable JSON results with editing disabled." }
  ]
