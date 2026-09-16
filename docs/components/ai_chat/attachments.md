# `ai_chat_attachments`

> Status: built
> Tier: 2 (small element)
> Relates to: [composer](composer.md), [message](message.md), [workspace](workspace.md)

## As built

Where the build differs from this note:

- There is no `ai_chat_attachment_chips` helper: the chips go into the composer's `[data-ai-chat-chips]`, which the dropzone names with `chips:`.
- An uploading dropzone needs `field:`, the name the uploaded `value`s are posted under. The upload's contract is a POST of `file` answered with JSON carrying `value`.
- The chip is cloned from a `<template data-dropzone-chip>` the helper renders, so the chip's markup is the server's rather than built in script.
- Thumbnails only, as the open question proposed.

## Purpose

Files on their way into a conversation: the drop zone that takes them, the chips
that show what is attached and not yet sent, and the tiles that show what was
attached once it has been.

kp2 and toybox both built this and disagreed productively about the drop target.
kp2 makes the whole thread a zone; toybox makes the whole page one, arguing that
there is no smaller target that would be honest — a reference image belongs to
the conversation rather than to the box you type in, and aiming at a strip above
the composer is a worse version of the same thing. toybox is right, so the zone
is a wrapper the caller puts wherever it belongs, and the note recommends the
page.

For attaching to a turn. Not for a general file field — `FormBuilder` has one —
and not for the agent's own output, which is [workspace](workspace.md).

## API

```erb
<%# The zone: wrapping whatever should accept a drop %>
<%= ai_chat_dropzone url: workspace_files_path(chat), input: "#composer_files",
      label: "Drop to add to the conversation" do %>
  …the whole page…
<% end %>

<%# The chips, inside the composer %>
<%= ai_chat_attachment_chips %>

<%# What a sent turn carries %>
<%= ai_chat_attachments do |a| %>
  <% message.attachments.each do |blob| %>
    <% a.file blob.filename, size: blob.byte_size, url: url_for(blob),
         thumbnail: (url_for(blob.variant(:thumb)) if blob.image?) %>
  <% end %>
<% end %>
```

| Option (`ai_chat_dropzone`) | Values | Default | Notes |
|---|---|---|---|
| `url:` | path | `nil` | Upload immediately; `nil` means hold in the input |
| `input:` | selector | required | The file input files land in |
| `label:` | string | a default | The overlay's words |

| Option (`ai_chat_attachments`) | Values | Default | Notes |
|---|---|---|---|
| `align:` | `:start`, `:end` | `:start` | `:end` for a user turn, which is right-aligned |

Builder part: `a.file(name, size:, url:, thumbnail:, removable:)`.

The two upload strategies are both real and the note names both, because the
applications need both: on a conversation that exists the file goes to the
workspace on the spot and a chip carrying its path goes on the composer, so
sending the message hangs the bytes off the question. Before there is a
conversation there is nowhere to put anything, so the input keeps what it is
given and posts it with the form.

## Markup

```html
<unmagic-dropzone url="…" input="#composer_files" class="UnmagicAIChatDropzone">
  <div class="UnmagicAIChatDropzone__overlay" aria-hidden="true">
    <p>Drop to add to the conversation</p>
  </div>
  <!-- the caller's content -->
</unmagic-dropzone>

<ul class="UnmagicAIChatAttachments UnmagicAIChatAttachments--end">
  <li class="UnmagicAIChatAttachments__file">
    <img class="UnmagicAIChatAttachments__thumb" alt="">
    <span class="UnmagicAIChatAttachments__name">brief.pdf</span>
    <span class="UnmagicAIChatAttachments__size">204 KB</span>
    <button type="button" class="UnmagicAIChatAttachments__remove" aria-label="Remove brief.pdf">…</button>
  </li>
</ul>
```

The overlay is `pointer-events: none` and outside the content flow: it cannot
take the drop it is advertising, and it must not shift the page when it appears.

## Accessibility

- Drag and drop is never the only way in. The component requires a paired file
  input, and [composer](composer.md) renders the attach control over it.
- The overlay is `aria-hidden`: it is feedback for a pointer gesture that no
  keyboard user can perform.
- A dropped file is announced once through a polite live region — "brief.pdf
  attached" — because otherwise nothing tells a non-visual reader the drop
  landed.
- Remove buttons have `aria-label` naming the file, not a bare "Remove".
- Thumbnails are decorative (`alt=""`); the filename beside them is the name.

## Styling

CSS section: **AI chat attachments**.

- `.UnmagicAIChatDropzone`, `__overlay`
- `.UnmagicAIChatAttachments`, `--start`, `--end`, `__file`, `__thumb`,
  `__name`, `__size`, `__remove`

The overlay shows from an attribute the element sets, not a class:

```css
.UnmagicAIChatDropzone__overlay { @apply pointer-events-none absolute inset-0 z-10 hidden place-items-center; }
.UnmagicAIChatDropzone[data-dragging] .UnmagicAIChatDropzone__overlay { @apply grid; }
```

Dashed `border-2 border-dashed border-neutral-400` over a translucent neutral,
with the dark pair. Chips are `rounded-lg border px-2 py-1 text-xs`.

Motion: the overlay fades in over 100ms, switched off under reduced motion.

## Behaviour (JavaScript)

`<unmagic-dropzone>` — reads `url` and `input`.

- `dragenter`/`dragleave` with a counter (not a boolean — `dragleave` fires
  crossing every child), setting `data-dragging`.
- `drop` and `paste` both route to the same handler, since pasting an image is
  the same gesture by another name.
- With a `url`, upload each file and append a chip with the returned path plus a
  hidden field, so what the reader can see and what the form posts cannot
  disagree. Without one, put the files on the named input.
- Fires `unmagic-dropzone:attach` and `unmagic-dropzone:error`, bubbling.
- Clears its chips on the form's `turbo:submit-end` with `success`.
- Turbo: listeners on the element go in the constructor; the drag counter resets
  on `turbo:before-cache`, so a cached snapshot is never stuck showing the
  overlay.
- Needs Turbo only for the submit-end clearing.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.attachments.drop` | "Drop to attach" |
| `unmagic.components.ai_chat.attachments.attached` | "%{name} attached" |
| `unmagic.components.ai_chat.attachments.remove` | "Remove %{name}" |
| `unmagic.components.ai_chat.attachments.failed` | "Couldn't attach %{name}" |

## Specs

`spec/unmagic/components/ai_chat_attachments_spec.rb`:

- The zone's element, attributes, and the overlay's `aria-hidden`.
- Chips render name, humanised size, thumbnail when given and not otherwise.
- `align:` classes, and `ArgumentError` for an unknown one.
- Remove buttons carry a naming `aria-label`, and are absent when
  `removable: false`.
- The live region exists and is polite.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A zone around a boxed area with a composer inside it; a row of
chips; a row of sent-turn tiles including an image and a non-image; and a
right-aligned set.

By hand: drag a file over and out (the overlay must not flicker crossing
children); paste an image; remove a chip; keyboard reach to the remove buttons;
dark theme; reduced motion.

## Open questions

- Should the gem render media previews — an image that shows, audio that plays?
  toybox's tiles do, and they are good, but they pull in viewers for four media
  categories. Proposed: thumbnails only in this round. `a.file` takes a
  `thumbnail:` and a block, so a host can put its own player in.
