# `ai_chat_permission`

> Status: draft
> Tier: 2 (small element)
> Relates to: [request](request.md), the confirm dialog, `badge`

## Purpose

An agent asking to be allowed something, with the answer sitting right under the
reasoning rather than in a dialog that arrived without it.

This is the highest-stakes surface in the family: it is where somebody is asked
to agree to something on the agent's behalf. Two things follow from that, and
both come from toybox, which is the only one of the three applications to have
built it:

- **What is being asked for is a line of its own, above the reasoning** — the
  tool, and the arguments it is wanted for. That is the part the decision is
  actually about; the summary underneath is the agent's case for it.
- **A grant stays granted, and the transcript is the only place it is written
  down.** The answered card says which way it went, and says plainly when a
  request lapsed without anything being granted at all.

Not [request](request.md). A question is a question; this is a gate, it has a
confirmation, it can be widened beyond the conversation that asked, and getting
it wrong has consequences a wrong answer does not.

Only toybox has this, so this note argues for it rather than writing down a
consensus. The argument: every one of these applications is heading for tools
that delete things, spend money or reach into another conversation, and the one
that got there first built this. It is becoming table stakes, and it is much
better built once.

## API

```erb
<%= ai_chat_permission tool: asked["tool"], state: permission_state, url: permission_path(chat, call),
      id: dom_id(call) do |p| %>
  <% wanted.each { |name, value| p.argument name, value } %>
  <% p.summary { markdown asked["summary"] } %>
  <% p.reason { markdown asked["reason"] } %>
  <% asked["examples"].first(5).each { |e| p.example e } %>

  <% p.allow confirm: "Let this chat use #{asked["tool"]} as it asked?" %>
  <% p.allow "Allow for any chat", params: { permission: { widened: true } },
       confirm: "Let this chat use #{asked["tool"]} on any conversation?" %>
  <% p.refuse %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `tool:` | string | required | The tool's own name, unchanged |
| `state:` | `:waiting`, `:granted`, `:refused`, `:lapsed` | required | Validated; raises `ArgumentError` |
| `url:` | path | required when `:waiting` | |
| `id:` | string | `nil` | For `upsert` |
| `outcome:` | string | derived | The sentence an answered card shows |

Builder parts: `p.argument(name, value)`, `p.summary { }`, `p.reason { }`,
`p.example(text)`, `p.allow(label, params:, confirm:)`, `p.refuse(label,
confirm:)`.

`p.allow` is repeatable, which is how the second, wider grant is offered — and it
is offered only when there is something left to widen. A model can ask for a
wildcard itself, and then there is nothing to widen and the button is not drawn.
The gem cannot know that; the host decides whether to record the second `allow`.
The note says so because getting it wrong hands somebody more than they agreed
to.

The tool name is the same string in the card, the record and the transcript,
never translated into friendlier words. It is what will be called and what the
permission is written down against.

`state: :lapsed` is the case toybox found and named: a request answered in the
composer, because somebody typed a reply rather than pressing a button. Nothing
was granted either way, and the card says that rather than guessing.

## Markup

```html
<div id="tool_call_9" class="UnmagicAIChatPermission UnmagicAIChatPermission--waiting">
  <div class="UnmagicAIChatPermission__head">
    <svg aria-hidden="true">…</svg> Wants permission
  </div>

  <p class="UnmagicAIChatPermission__ask">
    <code>delete_resource</code>
    <span class="UnmagicAIChatPermission__argument">chat_id: 42</span>
  </p>

  <div class="UnmagicAIChatPermission__summary UnmagicProse">…</div>
  <div class="UnmagicAIChatPermission__reason UnmagicProse">…</div>
  <ul class="UnmagicAIChatPermission__examples">…</ul>

  <div class="UnmagicAIChatPermission__actions">…</div>
</div>
```

Each action is a `button_to` — a non-GET mutation, per the gem's own rule — with
`data-turbo-confirm` where a confirmation is given, which routes through the
gem's existing confirm dialog.

## Accessibility

- `role="alertdialog"` was considered and rejected. It is not a dialog: it lands
  in the transcript, in place, with its reasoning, and moving it into a modal is
  exactly the failure this component exists to avoid. It is `role="alert"` when
  streamed in, like [request](request.md).
- The icon is `aria-hidden`; "Wants permission" is text.
- Destructive and non-destructive grants are distinguished by their confirmation
  wording, not only by colour. The confirmation for a tool nothing can undo is
  sterner than for a look inside another conversation — one dialog for both would
  either cry wolf or wave a deletion through.
- Allow is the visually prominent control but is **not** the autofocused one and
  not the default submit. Focus goes to the card, not to a button, so a stray
  Enter cannot grant anything.
- Examples are a real list.

## Styling

CSS section: **AI chat permissions**, immediately after **AI chat requests** — they
share the amber and should be read together.

- `.UnmagicAIChatPermission`, `--waiting`, `--granted`, `--refused`, `--lapsed`
- `__head`, `__ask`, `__argument`, `__summary`, `__reason`, `__examples`,
  `__actions`, `__outcome`

Waiting is the same amber card as `ai_chat_request`. The Allow button is the one
red control in the family: `bg-red-600 text-white hover:bg-red-500`. Red for the
*affirmative* is deliberate and worth the comment in the CSS — it is not an
error, it is the consequential choice, and the gem's usual "primary is
prominent" instinct is wrong here.

The answered outcome reads in red when granted and neutral when refused, for the
same reason: a grant is what somebody would want to spot later.

## Behaviour (JavaScript)

None of its own. Confirmation goes through the gem's existing confirm dialog via
`data-turbo-confirm`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.permission.waiting` | "Wants permission" |
| `unmagic.components.ai_chat.permission.asked` | "Wanted permission" |
| `unmagic.components.ai_chat.permission.allow` | "Allow" |
| `unmagic.components.ai_chat.permission.refuse` | "Refuse" |
| `unmagic.components.ai_chat.permission.granted` | "Allowed." |
| `unmagic.components.ai_chat.permission.refused` | "Refused." |
| `unmagic.components.ai_chat.permission.lapsed` | "Answered in the chat — nothing was granted." |

## Specs

`spec/unmagic/components/ai_chat_permission_spec.rb`:

- Each state's classes, heading tense and outcome sentence.
- A waiting card renders its actions; an answered one renders none.
- Repeated `p.allow` renders several buttons, each with its own params and
  confirmation.
- `data-turbo-confirm` reaches the form, not the button.
- The tool name renders verbatim, in a `<code>`.
- Arguments render as name/value pairs in the ask line.
- `role="alert"` only when `live: true`.
- `ArgumentError` for an unknown state.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A waiting card with one grant; one with a widening second grant;
one with five examples; and one in each answered state including `:lapsed`.

By hand: confirm dialogs fire and their wording differs; keyboard through the
actions and confirm Enter does not grant; dark theme.

## Open questions

- Should the gem render a standing summary of what has been granted — toybox's
  `chat_permissions_tag` badges? It is genuinely useful and genuinely
  application-shaped (it knows which tools are irreversible). Proposed: out of
  this round; `badge` already covers the markup and the policy is the host's.
