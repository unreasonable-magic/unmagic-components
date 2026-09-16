# `ai_chat_workspace`

> Status: draft
> Tier: 1 (no JS)
> Relates to: [plan](plan.md), [attachments](attachments.md), [`../tree_view`](../tree_view.md), `card`

## Purpose

The files the agent has put aside while it works — captures, notes, renders,
scratch data — so a person can see what it has actually produced rather than
inferring it from the prose.

hooops and toybox both built this and both docked it under the plan in a side
panel. hooops renders a real tree (it reuses the file explorer from elsewhere in
the app); toybox renders a flat list. The tree is right when paths nest and
overkill when they do not, so the component does both and decides from the paths
it is given.

For the agent's own output. Not for what a person attached — that is
[attachments](attachments.md) — and not for a file browser, which is the planned
[`tree_view`](../tree_view.md) this should be built on rather than beside.

## API

```erb
<%= ai_chat_workspace count: files.size do |workspace| %>
  <% files.each do |file| %>
    <% workspace.file file.path, size: file.byte_size, url: file_path(file) %>
  <% end %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `title:` | string | "Workspace" | |
| `open:` | boolean | `true` | |
| `count:` | integer | counted from the files | The reading beside the title |
| `empty:` | string | a default sentence | |
| `tree:` | boolean | inferred | Force the nested or the flat rendering |

Builder part: `workspace.file(path, size:, url:, icon:)`.

- `path` is the full path; the tree is derived from it. Giving flat names yields a
  flat list, which is why `tree:` rarely needs setting.
- Like [plan](plan.md), it renders its empty state rather than nothing, because
  it is a broadcast target.
- A file with no `url:` is not a link. Both applications' workspaces are
  read-only in the UI, and a link that goes nowhere is worse than plain text.

## Markup

```html
<details id="workspace" class="UnmagicAIChatWorkspace" open>
  <summary class="UnmagicAIChatWorkspace__head">
    <svg aria-hidden="true">…</svg>
    <h2 class="UnmagicAIChatWorkspace__title">Workspace</h2>
    <p class="UnmagicAIChatWorkspace__count">4</p>
  </summary>

  <ul class="UnmagicAIChatWorkspace__files" role="tree">
    <li role="treeitem" class="UnmagicAIChatWorkspace__folder" aria-expanded="true">
      <span>captures/</span>
      <ul role="group">
        <li role="treeitem" class="UnmagicAIChatWorkspace__file" style="--unmagic-ai-chat-workspace-depth: 1">
          <svg aria-hidden="true">…</svg>
          <span class="UnmagicAIChatWorkspace__name">brief.png</span>
          <span class="UnmagicAIChatWorkspace__size">42 KB</span>
        </li>
      </ul>
    </li>
  </ul>
</details>
```

The flat rendering drops the `role="tree"` wiring entirely and is a plain `<ul>`
— a list of four files is not a tree and should not be announced as one.

## Accessibility

- Nested: the WAI-ARIA [tree view pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/),
  which [`tree_view`](../tree_view.md) is already designing. This component
  should use it rather than reimplement it, and that is the main thing to settle
  before building.
- Flat: a plain list, no tree roles.
- File-type icons are `aria-hidden`; the name is the text.
- Sizes are `tabular-nums` and read after the name.
- Each file carries a `title` with its full path, since the tree shows only the
  leaf.

## Styling

CSS section: **AI chat workspace**, next to **AI chat plans** — they are two sections
of one panel and share a divider in every application that has both.

- `.UnmagicAIChatWorkspace`, `__head`, `__title`, `__count`, `__files`,
  `__folder`, `__file`, `__name`, `__size`

Indentation is a knob, so the depth arithmetic lives in CSS rather than in an
inline `style` computed in Ruby:

```css
.UnmagicAIChatWorkspace__file { padding-inline-start: calc(0.5rem + var(--unmagic-ai-chat-workspace-depth, 0) * 0.75rem); }
```

`--unmagic-ai-chat-workspace-depth` is the component's only knob, named per the
principles, carrying a layout value for one instance.

Colours: neutrals only. Motion: none.

## Behaviour (JavaScript)

None of its own if flat. Nested rendering uses whatever
[`tree_view`](../tree_view.md) ships for keyboard navigation.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.workspace.title` | "Workspace" |
| `unmagic.components.ai_chat.workspace.empty` | "No files yet." |

## Specs

`spec/unmagic/components/ai_chat_workspace_spec.rb`:

- Flat paths render a plain list with no tree roles; nested paths render the tree.
- `tree:` forcing each way.
- The count from the files, and an explicit `count:` overriding it.
- The empty sentence, with the element still rendered.
- A file with a url is a link; one without is not.
- The depth knob's value per level.
- `title` carrying the full path.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A flat workspace; a nested one three levels deep; an empty one;
and both docked under a plan in a card, which is the layout they ship in.

By hand: keyboard through the tree; dark theme; long filenames truncate rather
than wrapping the size off the edge.

## Open questions

- **Build order.** This should not be built before
  [`tree_view`](../tree_view.md), or the gem ends up with two tree
  implementations. Proposed: ship the flat rendering in this round and add the
  nested one when `tree_view` lands. The API does not change.
