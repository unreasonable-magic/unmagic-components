// Heavy runtime: reached only through the custom element's dynamic import.
import { basicSetup, EditorView } from "unmagic/components/code_editor/vendor/codemirror"
import { EditorState } from "unmagic/components/code_editor/vendor/@codemirror--state"
import { HighlightStyle, syntaxHighlighting } from "unmagic/components/code_editor/vendor/@codemirror--language"
import { tags } from "unmagic/components/code_editor/vendor/@lezer--highlight"

// Each loader is a separate import so unrelated languages stay off the network.
const languageLoaders = {
  javascript: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-javascript")).javascript(),
  typescript: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-javascript")).javascript({ typescript: true }),
  python: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-python")).python(),
  html: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-html")).html(),
  css: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-css")).css(),
  sql: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-sql")).sql(),
  java: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-java")).java(),
  cpp: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-cpp")).cpp(),
  go: async () => (await import("unmagic/components/code_editor/vendor/@codemirror--lang-go")).go(),
  ruby: async () => {
    const [{ ruby }, { StreamLanguage }] = await Promise.all([
      import("unmagic/components/code_editor/vendor/@codemirror--legacy-ruby"),
      import("unmagic/components/code_editor/vendor/@codemirror--language"),
    ])
    return StreamLanguage.define(ruby)
  },
}

export async function createEditor(element, textarea, changed) {
  const extensions = []
  const language = element.getAttribute("language")
  if (languageLoaders[language]) {
    extensions.push(await languageLoaders[language]())
  } else if (language === "json") {
    const { json } = await import("unmagic/components/code_editor/vendor/@codemirror--lang-json")
    extensions.push(json())
  } else if (language === "graphql") {
    const [{ graphql }, { buildSchema }] = await Promise.all([
      import("unmagic/components/code_editor/vendor/cm6-graphql"),
      import("unmagic/components/code_editor/vendor/graphql"),
    ])
    extensions.push(graphql(element.getAttribute("schema") ? buildSchema(element.getAttribute("schema")) : undefined))
  }
  const attributes = {}
  for (const name of ["aria-label", "aria-labelledby", "aria-describedby", "aria-invalid", "aria-required"])
    if (textarea.hasAttribute(name)) attributes[name] = textarea.getAttribute(name)
  if (!attributes["aria-label"] && !attributes["aria-labelledby"])
    attributes["aria-label"] = Array.from(textarea.labels || []).map(label => label.textContent.trim()).join(" ") || textarea.name || "Code"
  if (textarea.required) attributes["aria-required"] = "true"
  attributes["aria-disabled"] = String(textarea.disabled)
  attributes["aria-readonly"] = String(textarea.readOnly)
  return new EditorView({
    parent: element.querySelector("[data-editor-mount]"),
    doc: textarea.value,
    extensions: [
      basicSetup,
      EditorView.lineWrapping,
      EditorState.readOnly.of(textarea.readOnly || textarea.disabled),
      EditorView.editable.of(!textarea.disabled && !textarea.readOnly),
      EditorView.contentAttributes.of({ ...attributes, tabindex: textarea.disabled ? "-1" : "0" }),
      EditorView.updateListener.of(update => { if (update.docChanged) changed() }),
      syntaxHighlighting(HighlightStyle.define([
        { tag: tags.keyword, class: "UnmagicCodeEditor__keyword" },
        { tag: [tags.typeName, tags.definition(tags.variableName)], class: "UnmagicCodeEditor__type" },
        { tag: tags.string, class: "UnmagicCodeEditor__string" },
        { tag: [tags.number, tags.bool, tags.null], class: "UnmagicCodeEditor__number" },
        { tag: tags.comment, class: "UnmagicCodeEditor__comment" },
      ])),
      ...extensions,
    ],
  })
}
