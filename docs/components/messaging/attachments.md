# `message_attachments`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: `ai_chat_attachments` (now an alias of this),
> `ai_chat_dropzone` (which renders this component's chip), `message`

## Purpose

The files that came with a message, as tiles: a glyph or thumbnail, the name
and the size, linked to the file. Rendered into `message.attachments { }`.

This is `ai_chat_attachments` moved out of the AI chat family. The tiles were
never about agents, and the drop zone that takes files before they're sent keeps
drawing the same tile for a pending one.

## API

```erb
<%= message_attachments do |files| %>
  <% files.file "Tech requirements.pdf", size: 1_258_291, url: rails_blob_path(blob) %>
  <% files.file "cover.png", size: 40_960, url: "…", thumbnail: "…" %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `align:` | `:start`, `:end` | `:start` | Which side the tiles gather on |

`files.file(name, size: nil, url: nil, thumbnail: nil)`. No files renders
nothing. Other options go on the `<ul>`.

## Markup

```html
<ul class="UnmagicMessageAttachments UnmagicMessageAttachments--end">
  <li class="UnmagicMessageAttachments__file">
    <a class="UnmagicMessageAttachments__link" href="…">
      <svg class="UnmagicIcon UnmagicMessageAttachments__glyph" aria-hidden="true">…</svg>
      <span class="UnmagicMessageAttachments__name">Tech requirements.pdf</span>
      <span class="UnmagicMessageAttachments__size">1.2 MB</span>
    </a>
  </li>
</ul>
```

Unchanged from `ai_chat_attachments` but for the block name. The drop zone's
chip (`UnmagicMessageAttachments__file` with a `__remove` button) is the same
tile.

## Accessibility

- A list of links named by the file name; the thumbnail is decoration
  (`alt=""`) and the glyph is `aria-hidden`.
- The remove button on a pending chip is labelled by the drop zone.

## Styling

CSS section: **Message attachments** (the former "AI chat attachments" section,
renamed; the drop zone's own rules stay in the AI chat family).

- `.UnmagicMessageAttachments`, `--end`, `__file`, `__link`, `__thumb`,
  `__glyph`, `__name`, `__size`, `__remove`
- Colours and sizes as before: a tile is `rounded-lg border border-neutral-200
  bg-white text-xs text-neutral-700` with `dark:` pairs.

## Small screens

Tiles wrap and are at most `max-w-64`; a long name truncates.

## Behaviour (JavaScript)

_None._ `<unmagic-dropzone>` clones the chip; it finds it by `data-dropzone-*`
attributes, not by class.

## I18n

None of its own.

## Specs

The existing `ai_chat_attachments` examples in `ai_chat_extras_spec.rb`, on the
new class names, plus `message_attachments` rendering the same.

## Preview

Page: `message_attachments`: files with sizes, a thumbnail, aligned to the end
under an own bubble. The `ai_chat_attachments` page is retired in its favour.
