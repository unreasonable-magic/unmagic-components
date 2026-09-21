# `ai_chat_workspace`

> Status: built
> Tier: 1 (no JS of its own; `ai_chat.js` keeps a reader's choice)
> Relates to: [plan](plan.md), [attachments](attachments.md), [`../tree_view`](../tree_view.md), `card`

## As built

Where the build differs from this note:

- **Always a tree, drawn with [`tree_view`](../tree_view.md).** There is no
  `tree:` option: paths with no folders render as a tree with no branches,
  which is a plain list of leaves anyway (`tree_view` uses nested `<ul>`s and
  `<details>`, not `role="tree"`), so there is nothing to force either way.
- **No depth knob.** `tree_view`'s nesting indents each level, so
  `--unmagic-ai-chat-workspace-depth` isn't needed.
- The first build was a flat list with each file's directory dimmed before its
  name. It was replaced by the tree, and its long-path bug (the ellipsis ate the
  file name) went with it; see Decisions.

## Decisions

- **The caller gives paths; the workspace builds the folders.**
  `workspace.file(path, size:, url:, icon:)` is unchanged. Paths are split on
  `/`, ignoring empty and `.` segments, so `/scratch/./data/rows.csv` sits in
  `scratch/data`.
- **Order.** Folders keep the order their first file arrived in, and come
  before the files beside them; files keep the order they were given. A caller
  who wants them sorted sorts them.
- **Folders start open.** The workspace is there to show what the agent made,
  so nothing is hidden until someone folds it. A broadcast or a morph that
  replaces the workspace opens them again, which is the server's state.
- **A folder that holds only one folder joins it** in a single row
  (`careers.example.com/jobs`), as editors compact folders: a deep path costs
  one row, not one per level. A folder holding a single file stays a folder,
  so every file sits under the folder it's in.
- **The name that matters is never truncated away.** A file's row is its name
  alone (the full path is its `title`), and truncates only when the name by
  itself doesn't fit, while its size stays whole (`tree_view`'s `meta:`). A
  joined folder row is split into `__directory` and `__name`: the leading
  folders shorten first, and the last folder's name keeps its room.
- **A glyph per kind of file.** Without `icon:`, the extension picks one of
  Lucide's file glyphs from `Workspace::FILE_ICONS`: `file_code` (html, rb, js,
  css, yml, …), `file_text` (md, txt, pdf, …), `file_image`, `file_json`,
  `file_spreadsheet` (csv, xlsx, …), `file_archive`, `file_audio` and
  `file_video`; anything else, or no extension, is `file`. An explicit `icon:`
  wins. `Workspace.icon_for(path)` answers the same question for a caller.
- **The count is the number of files**, not rows or folders.

## Purpose

The files the agent has put aside while it works — captures, notes, renders,
scratch data — so a person can see what it has actually produced rather than
inferring it from the prose.

Applications that have built this dock it under the plan in a side panel. Some
render a real tree, some a flat list. The tree is right when paths nest, and
when they don't it is just a list, so the component always builds the tree
from the paths it is given.

For the agent's own output. Not for what a person attached — that is
[attachments](attachments.md) — and not for a file browser, which is
[`tree_view`](../tree_view.md), the component this one draws its tree with.

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
| `title:` | string | "Workspace" | Also the tree's `aria-label` |
| `open:` | boolean | `true` | The section, not its folders |
| `count:` | integer | counted from the files | The reading beside the title |
| `empty:` | string | a default sentence | |
| `collapsible:` | boolean | `true` | `false` renders a plain section |
| `title_tag:` | symbol | `:h2` | |

Builder part: `workspace.file(path, size:, url:, icon:)`.

- `path` is the full path; the folders are derived from it.
- `size:` is bytes, shown with `number_to_human_size`.
- `icon:` is an icon name; without it the extension picks one.
- Like [plan](plan.md), it renders its empty state rather than nothing, because
  it is a broadcast target.
- A file with no `url:` is not a link. Workspaces are usually read-only in the
  UI, and a link that goes nowhere is worse than plain text.

## Markup

```html
<details id="workspace" class="UnmagicAIChatWorkspace" open>
  <summary class="UnmagicAIChatWorkspace__head">
    <svg aria-hidden="true">…folder…</svg>
    <h2 class="UnmagicAIChatWorkspace__title">Workspace</h2>
    <svg class="UnmagicAIChatChevron" aria-hidden="true">…</svg>
    <span class="UnmagicAIChatWorkspace__count">3</span>
  </summary>

  <ul class="UnmagicTree UnmagicTree--guides UnmagicAIChatWorkspace__files" aria-label="Workspace">
    <li class="UnmagicTree__node">
      <details class="UnmagicTree__branch" open>
        <summary class="UnmagicTree__row UnmagicAIChatWorkspace__folder" title="captures/example.com/jobs">
          <svg class="UnmagicTree__toggle" aria-hidden="true">…</svg>
          <svg class="UnmagicTree__icon" aria-hidden="true">…folder…</svg>
          <span class="UnmagicTree__label">
            <span class="UnmagicAIChatWorkspace__path">
              <span class="UnmagicAIChatWorkspace__directory">captures/example.com</span>
              <span class="UnmagicAIChatWorkspace__name">/jobs</span>
            </span>
          </span>
        </summary>
        <ul class="UnmagicTree__children">
          <li class="UnmagicTree__node">
            <a class="UnmagicTree__row UnmagicTree__row--leaf UnmagicAIChatWorkspace__file"
               href="/files/1" title="captures/example.com/jobs/senior-engineer.html">
              <svg class="UnmagicTree__icon" aria-hidden="true">…file-code…</svg>
              <span class="UnmagicTree__label">senior-engineer.html</span>
              <span class="UnmagicTree__meta">82 KB</span>
            </a>
          </li>
        </ul>
      </details>
    </li>
    <li class="UnmagicTree__node">
      <span class="UnmagicTree__row UnmagicTree__row--leaf UnmagicAIChatWorkspace__file" title="notes.md">…</span>
    </li>
  </ul>
</details>
```

## Accessibility

- Whatever [`tree_view`](../tree_view.md) gives: nested lists that announce
  their level and size, and folders as `<summary>` rows, expandable buttons
  that Enter or Space folds. Tab moves through the open rows. No
  `role="tree"`, which would promise arrow keys this tier doesn't have.
- The tree is labelled with the section's title.
- File-type icons are `aria-hidden`; the name is the text.
- Sizes are `tabular-nums` and read after the name.
- Each row carries a `title` with its full path, since the tree shows only the
  last part.

## Styling

CSS section: **AI chat workspace**, after **AI chat plans**: they are two
sections of one panel and share a divider.

- `.UnmagicAIChatWorkspace`, `__head`, `__title`, `__count`, `__empty`, shared
  with the plan.
- `__files` is the tree's root: it reaches into the section's padding
  (`-mx-2`), so a top-level chevron sits under the section's glyph and hover
  fills the panel's width.
- `__folder` and `__file` are the tree's rows, in `neutral-700` /
  `dark:neutral-300`.
- `__path`, `__directory`, `__name` split a joined folder row: `__directory` is
  `min-w-0 truncate` in `neutral-500` / `dark:neutral-400`, and `__name` is
  `shrink-0 max-w-full truncate`.
- A tree row keeps its own rounded focus ring over the AI chat family's
  squarer summary ring.

Colours: neutrals only. Motion: the chevron's turn, off under reduced motion
(`tree_view`'s).

## Small screens

`tree_view`'s: folder and file-link rows are at least 44px tall where the
pointer is coarse; names truncate and sizes stay whole.

## Behaviour (JavaScript)

None. `<details>` folds the folders.

Like the [plan](plan.md), a workspace given an `id:` keeps the person's open or
shut across broadcasts: `ai_chat.js` reapplies their last choice to the
replacement. The server's `open:` decides until they choose.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.workspace.title` | "Workspace" |
| `unmagic.components.ai_chat.workspace.empty` | "No files yet." |

## Specs

`spec/unmagic/components/ai_chat_panels_spec.rb`:

- Files sharing a directory sit once under an open, collapsible folder; a file
  with a url is a link and one without is not; the size and the full-path
  `title`.
- Nesting, folders before files, a joined single-folder chain split into
  `__directory` and `__name`, and `.` or empty segments ignored.
- The icon from the extension for each kind, the fallback to `file`, an
  explicit `icon:` winning, and every mapped icon existing.
- The count from the files, and an explicit `count:` overriding it.
- The empty sentence, with the element still rendered.
- Passthrough `class:`.

## Preview

Page: `ai_chat_workspace`. Files beside a plan, the layout they ship in; and a
narrow panel with nested folders, a dozen files in one folder, a joined
folder chain and a very long file name.

By hand: Tab through the folders and fold one with Enter; dark theme; the
joined row keeps its last folder's name at a narrow width.

## Open questions

- **Folder state across broadcasts.** A replaced workspace opens every folder
  again. Remembering what a person folded would need script (Tier 2), as would
  arrow-key navigation; both wait on a scripted `tree_view`.
