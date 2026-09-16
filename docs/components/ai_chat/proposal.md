# `ai_chat_proposal`

> Status: built
> Tier: 1 (no JS)
> Relates to: [request](request.md), [citation](citation.md), `card`

## As built

Where the build differs from this note:

- Built as described; the default icon is `:lightbulb`.

## Purpose

An inline card for something the agent proposed mid-reply, with its approve and
dismiss actions while pending, settling into a quiet decided state afterwards.

This is the closest thing in the family to assistant-ui's generative Tool UI, and
it comes from kp2, where one `proposal` layout is reused by four different domain
objects: a fact it inferred about someone, a new dimension it suggested tracking,
a standing instruction it derived, and a chart it drew. The shape is identical
every time — glyph, claim, a line of context under it, actions on the right — and
it is the shape *because* it has to sit inside a reply's prose without becoming
the reply.

The distinction from [request](request.md) is the whole reason it is a separate
component: a request stops the work and waits. A proposal does not. The agent
carries on; the card is an offer the reader can take up whenever, including never.
An agent that blocked on every inference would be unusable.

For an offer the agent makes in passing. Not for a decision it needs before it
can continue, and not for a result it is simply reporting.

## API

```erb
<%= ai_chat_proposal icon: :lightbulb, state: fact.decision, id: dom_id(fact) do |p| %>
  <% p.claim { "Prefers to be called #{tag.strong(fact.short_name)}" } %>
  <% p.meta "About #{fact.subject.name} · 80% sure" %>

  <% p.accept { button_to "Save", memory_path(fact, decision: "approve"), method: :patch } %>
  <% p.reject { button_to "Dismiss", memory_path(fact, decision: "reject"), method: :patch } %>
<% end %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `state:` | `:pending`, `:accepted`, `:rejected` | `:pending` | Validated; raises `ArgumentError` |
| `icon:` | symbol | `nil` | The glyph that says what kind of proposal it is |
| `id:` | string | `nil` | For `upsert`, so every open tab re-renders it |

Builder parts: `p.claim { }`, `p.meta(text)`, `p.accept { }`, `p.reject { }`,
`p.outcome(text)`.

- `accept` and `reject` render only while `:pending`.
- Once decided it shows `outcome`, or a default from the state ("Saved",
  "Dismissed"). A rejected card dims, so it reads as dismissed without
  disappearing — the reader can still see what was offered and turned down.
- With no actions at all it is a plain inline card, which is how kp2's chart uses
  it.

The actions are the caller's markup rather than options, because each of kp2's
four proposals posts somewhere different with different words, and an options API
that covered all four would be four options wide.

## Markup

```html
<aside id="fact_7" class="UnmagicAIChatProposal UnmagicAIChatProposal--pending">
  <div class="UnmagicAIChatProposal__body">
    <svg class="UnmagicAIChatProposal__glyph" aria-hidden="true">…</svg>
    <div>
      <p class="UnmagicAIChatProposal__claim">…</p>
      <p class="UnmagicAIChatProposal__meta">…</p>
    </div>
  </div>
  <div class="UnmagicAIChatProposal__actions">…</div>
</aside>
```

`<aside>`, because that is exactly what it is: tangentially related content
beside the reply it appeared in.

## Accessibility

- `<aside>` gives it a landmark role, and the claim is its accessible name via
  `aria-labelledby`, so a reader tabbing through a long reply is told what each
  card is before reaching its buttons.
- Not a live region. It appears inside prose that is already being announced, and
  an agent that makes four inferences in a reply would otherwise interrupt four
  times.
- The decided state is text ("Saved", "Dismissed") with a glyph, never the
  dimming alone.
- `not-prose` is applied where it sits inside `UnmagicProse`, so the prose
  stylesheet's margins and list rules do not reach into the card. This is the one
  place the gem has to defend against its own stylesheet rather than a host's.

## Styling

CSS section: **AI chat proposals**.

- `.UnmagicAIChatProposal`, `--pending`, `--accepted`, `--rejected`
- `__body`, `__glyph`, `__claim`, `__meta`, `__actions`, `__outcome`

`rounded-lg border border-neutral-200 bg-neutral-50 px-2 py-1` with the dark
pairs — quieter than a `card`, because it sits *inside* a reply and a card-weight
box mid-paragraph reads as the end of the reply.

The glyph is blue (`text-blue-600 dark:text-blue-400`) — the gem's "info" tone,
since a proposal is neither good nor bad news.

`--rejected` adds `opacity-55`.

Motion: none. A card settling is a state change, not an animation.

## Behaviour (JavaScript)

None.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.ai_chat.proposal.accepted` | "Saved" |
| `unmagic.components.ai_chat.proposal.rejected` | "Dismissed" |

## Specs

`spec/unmagic/components/ai_chat_proposal_spec.rb`:

- Each state's classes and default outcome.
- Actions render only while pending.
- `outcome` overriding the default.
- The claim is the `aria-labelledby` target, with a derived id.
- `not-prose` present.
- `ArgumentError` for an unknown state.
- Passthrough `class:` and attributes.

## Preview

Page: `ai_chat`. A pending proposal with two actions; one accepted; one rejected;
one with no actions; and one nested inside a `UnmagicProse` block between two
paragraphs, which is the layout case that matters.

By hand: tab through a reply containing three of them and confirm each announces
its claim; dark theme.

## Open questions

- Should accepting a proposal be optimistic? All four of kp2's re-broadcast the
  card after the decision, which is a round trip the reader watches. Proposed:
  out of scope here — `<unmagic-optimistic>` already does this and the caller can
  reach for it, since the actions are the caller's markup.
