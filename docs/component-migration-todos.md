# Custom element migration todos

Status: draft. These are proposed migrations, not implemented APIs.

Move presentation decisions out of Ruby when a component can derive them from
its content, attributes, or neighbors. Keep Rails helpers as convenient adapters
that render content and public element attributes. Prioritize removing generated
decoration and conditional structure over replacing every class with a tag.

The examples below propose **light DOM**: `data-part` identifies content owned by
the caller; it is not a native slot. CSS addresses these children directly. An
element may add internal markup where behavior needs it, but must preserve caller
nodes, IDs, listeners, and stream targets. Shadow DOM is not required for this
plan. Names and exact attribute contracts need review in each component note.

## Migration order

| Order | TODO | Main benefit | Implementation |
|---|---|---|---|
| 0 | Define the element contract | One owner for rendering and state | Design and shared conventions |
| 1 | Tool calls and timeline connections | Remove conditional disclosure and connector markup from Ruby | CSS and JavaScript |
| 2 | Timeline markers and optional content | Remove numbering and marker layout decisions from Ruby | Mostly CSS |
| 3 | Reasoning | Respond to streamed content and state without rebuilding the panel | JavaScript and CSS |
| 4 | Plan and step elements | Derive counts and presentation from child state | JavaScript and CSS |
| 5 | Messages | Consolidate optional regions and streaming presentation | CSS and JavaScript |
| 6 | Card | Simplify header, body, and footer composition | CSS first |
| 7 | Page header and section | Remove unnecessary layout wrappers | CSS first |

## 0 Define the element contract

- [ ] Update [design principles](design-principles.md) with the proposed split.
  They currently require complete server rendering, semantic classes, and
  server-owned initial ARIA. Identify the precise exceptions needed for element
  generated structure; retain readable content and meaningful initial semantics.
- [ ] Refresh the affected component's design note and review its API before
  implementing it. This backlog does not change any existing note's built status.
- [ ] Specify direct-child parts, allowed repetition, absence, and blank content.
  Do not equate `:empty` with Ruby `blank?`: indentation and empty nested markup
  need an explicit policy. Preserve meaningful `0`, `false`, and empty payloads.
- [ ] Keep escaping, I18n, URLs, authorization, formatting seams, and option
  validation in Ruby. Direct HTML users supply equivalent content and labels.
  Define deterministic handling of invalid attributes for direct HTML users.
- [ ] Keep meaningful content as child HTML. Use attributes for configuration and
  state, rather than duplicating heading/body text in attributes and children.
- [ ] Define generated-node ownership and attribute reflection. Restrict observers
  to relevant caller content, avoid observing their own output indefinitely, and
  reconcile children arriving after `connectedCallback` as well as later streams.
- [ ] Keep global Tailwind component styles and utility overrides. Add JavaScript
  modules only when CSS cannot implement the behavior; styling a custom tag does
  not require registering an empty JavaScript class.
- [ ] Decide the icon and translated-status contract before stateful migrations:
  reuse current inline SVGs and server-provided translated label templates, or
  introduce one shared bundled icon mechanism. Do not copy glyph maps and English
  labels into every element. Accessible status must update with visible state.
- [ ] Preserve existing helper signatures. Introduce each new rendering path as
  opt-in while comparing output, then document the default switch and deprecation
  of old DOM/classes. Helper compatibility alone does not preserve host selectors.
- [ ] Keep IDs on documented stream targets. Never let generated structure make
  a Turbo append, replace, morph, or upsert overwrite unrelated caller content.

## 1 Tool calls and timeline connections

Implemented: the helper now always renders `<unmagic-tool-call>` with light-DOM
row/payload/result parts, dynamic native disclosure, shared reader-choice
preservation, and CSS connectors.
Reactive `state` attributes/properties now own glyphs, accessible status, busy
state, progress, and visibility of supplied timing/failure readings. Compact
direct HTML no longer needs internal classes or a row wrapper. See the
[implemented slice](components/ai_chat/tool_call.md#custom-element-api).

- [x] Introduce the element renderer and individual element import.
- [x] Switch repo consumers through the default helper, remove the duplicate Ruby
  renderer and decoration styles, and document the changed DOM/import contract.
- [x] Move disclosure creation/removal and connector decoration to JS/CSS.
- [x] Share reader-choice restoration with the existing AI chat behavior.
- [x] Observe state and translated labels; reflect state/name properties and
  preserve payload identity, selection, focus, and disclosure choice on updates.
- [x] Add helper/direct HTML examples and an end-to-end spec
  (`spec/e2e/ai_chat_tool_call_spec.rb`) covering streams, morphs, identity,
  focus, cloning, and reconnection.

Current code: [tool_call.rb](../lib/unmagic/components/ai_chat/tool_call.rb),
[ai_chat.js](../app/assets/javascripts/unmagic/components/ai_chat.js), and the
AI chat tool call section of [engine.css](../app/assets/tailwind/unmagic_components/engine.css).

Ruby supplies escaped content, translations, formatted readings and custom icon
templates. The element chooses disclosure structure and state presentation; CSS
detects adjacent timeline participants. The old Ruby presentation path and its
`__join`/`__rail` decoration spans have been removed.

Proposed public HTML:

```html
<unmagic-tool-call id="call_9" state="running" data-ai-chat-timeline="row"
  aria-busy="true">
  <code data-part="name">search_files</code>
  <span data-part="summary">Finding configuration files</span>
  <span data-part="status">Running</span>
  <p data-part="progress" id="call_9_progress">Searched 12 directories</p>
  <div data-part="payload" id="call_9_answer"><pre>...</pre></div>
  <div data-part="result"><a href="/files/config">config.yml</a></div>
</unmagic-tool-call>
```

Contract: `state` keeps `queued`, `running`, `waiting`, `done`, `failed`.
`open` supplies the initial disclosure preference; the reader's choice survives
updates with the same ID. Omit `data-ai-chat-timeline` for `timeline: false`.
`payload` is repeatable; `result` maps to the existing `made` builder method.
Status translations and glyph inputs follow TODO 0. Existing timing helpers can
render `data-part="elapsed"` and `data-part="duration"` readings containing
`<unmagic-elapsed>` or formatted text.

- [x] Add `tool_call.js`; make the Ruby builder emit public parts rather than
  deciding the entire internal structure in `render`, `disclosure`, and `row`.
- [x] Upgrade payload-bearing calls with native `<details>/<summary>`, keeping
  results outside the fold. React when the first payload arrives or the last is
  removed. Preserve focus and each payload node; before upgrade show all content.
- [x] Replace `__join` and `__rail` spans with CSS pseudo-elements where their
  geometry permits. Reuse the existing participant attribute across eligible
  types; permission and request panels continue to interrupt a run.
- [x] Specify whether `[hidden]` participants break a run. Initially preserve
  physical DOM adjacency; do not accidentally bridge messages or unrelated rows.
  Keep one marker column and consistent gap geometry for connected types.
- [x] Move progress visibility and state presentation to the element. Preserve
  the custom success icon, zero-failure suppression, and failed-state rules.
  Keep supplied failure counts and timing facts authoritative.
- [x] Integrate disclosure preservation with `ai_chat.js` before removing any
  existing hook. Avoid two competing stores of the same open/closed choice.
- [x] Verify streaming payload insertion/removal, running-to-done/failed changes,
  mixed adjacent participants, results outside the fold, keyboard focus, and
  reader-chosen disclosure state across replacement and Turbo restoration.

## 2 Timeline markers and optional content

Current code: [timeline.rb](../lib/unmagic/components/timeline.rb), especially
`marker`, `counter`, `alpha`, `roman`, and `header`. Existing CSS already draws
the connector and makes it dashed next to a pending item.

Proposed public HTML:

```html
<unmagic-timeline orientation="vertical" marker="lower-roman"
  role="list" aria-label="Deployment history">
  <unmagic-timeline-item role="listitem" tone="good">
    <a data-part="title" href="/deployments/9">Deployed</a>
    <time data-part="time" datetime="2026-10-02">2 October</time>
    <p data-part="description">Production is ready.</p>
  </unmagic-timeline-item>
  <unmagic-timeline-item role="listitem" pending>
    <span data-part="title">Verify deployment</span>
    <span data-part="status" class="UnmagicVisuallyHidden">Upcoming</span>
  </unmagic-timeline-item>
</unmagic-timeline>
```

Contract: preserve both orientations, the current marker enum, and tone values.
An optional `data-part="marker"` supplies an existing SVG or avatar; it overrides
the default marker. Title links remain real anchors. List/listitem semantics must
exist before upgrade; compare this API with retaining native `ol/li` if the new
tags do not justify the semantic and compatibility cost.

- [ ] Replace Ruby's `ROMAN`, `alpha`, `roman`, and positional counter strings
  with CSS counters for decorative numbering. Translate underscore enum values
  to CSS counter styles inside the stylesheet, not arbitrary CSS from attributes.
- [ ] Keep the decorative marker in an `aria-hidden` part when needed. Verify
  generated numbering is not announced in addition to the list position.
- [ ] Derive default marker, spacing, and title/time layout from supplied parts;
  preserve the fixed marker column for mixed icons, avatars, and counters.
- [ ] Keep native links and `LocalTime` rendering; retain Ruby validation of
  mutually exclusive icon/avatar options. Empty and skeleton output retain their
  documented behavior, including the loading announcement.
- [ ] Adapt the existing connector selectors to the new markup instead of
  replacing them with a JavaScript neighbor scanner.
- [ ] Verify append, remove, reorder, all marker styles, mixed markers, pending
  transitions, horizontal/mobile layouts, and list accessibility. Define whether
  hidden items contribute to numbering before adding filtering support.

## 3 Reasoning panels

Current code: [reasoning.rb](../lib/unmagic/components/ai_chat/reasoning.rb).
Ruby drops an empty settled panel, chooses a state-dependent title, and switches
between streaming markdown and ordinary blocks.

Proposed public HTML:

```html
<unmagic-reasoning id="reply_9_reasoning_panel" streaming>
  <span data-part="title">Thought process</span>
  <span data-part="status">Thinking…</span>
  <div data-part="body" id="reply_9_reasoning">Checking the configuration.</div>
</unmagic-reasoning>
```

Contract: `streaming` and initial `open`; optional formatted duration content in
`data-part="duration"`. `body` may be repeated and may contain existing streaming
markdown elements. Duration/title precedence must retain current behavior.

- [ ] Add `reasoning.js` to own disclosure, spinner/busy state, and empty-panel
  visibility. Retain an empty host as a stream target rather than deleting it.
- [ ] Keep title and body readable without JavaScript. Render localized thinking,
  settled, and duration labels through Ruby; select the appropriate supplied label
  on state changes rather than introducing English strings in JavaScript.
- [ ] Reuse `StreamingMarkdown` for reveal behavior. Avoid recreating its element
  when streaming stops, and scope emptiness detection so hidden source buffers or
  generated spinner text do not count as visible reasoning.
- [ ] Preserve the existing first-body ID contract: today `id:` identifies the
  first streaming block and disclosure key, not an outer host. Define an adapter
  and a distinct host ID before switching helper output.
- [ ] Verify empty-to-streaming-to-settled transitions, multiple blocks, duration
  labels, stream targeting, and persistent disclosure state.

## 4 Plans and steps

Current code: [plan.rb](../lib/unmagic/components/ai_chat/plan.rb) and
[AI chat section.rb](../lib/unmagic/components/ai_chat/section.rb).
Ruby counts completed steps, chooses the empty state, and builds state-specific
glyphs and waiting labels. `AIChat::Section` switches between details and section.

Proposed public HTML:

```html
<unmagic-plan id="plan_9" collapsible open>
  <h2 data-part="title">Plan</h2>
  <p data-part="empty">Nothing planned yet.</p>
  <ol data-part="steps">
    <li data-state="completed">Inspect configuration</li>
    <li data-state="in_progress">Run checks</li>
  </ol>
</unmagic-plan>
```

Contract: keep native list items; `data-state` retains the existing step enum.
Optional `completed` and `total` attributes override their respective derived
counts, including explicit zero, because the visible list may be partial.
Optional step detail is a child marked `data-part="detail"`; label HTML stays
caller supplied. Absent `collapsible` means a static panel; the existing helper
continues to emit it by default. `open` is an initial preference.

- [ ] Add `plan.js` to recompute count on direct step insertion, removal, and state
  changes. Keep explicit totals authoritative. Emit readable count text rather
  than relying on generated CSS content for meaningful progress.
- [ ] Move empty-state selection and state decoration out of `body` and `item`.
  Reuse translated labels, retaining a visible waiting label and accessible labels
  for the other states. Do not announce the whole plan after every count change.
- [ ] Extract only the disclosure behavior shared with tool calls/reasoning.
  Keep `AIChat::Section` working for workspaces until those migrate independently.
- [ ] Keep the stable empty host for broadcasts. Without JavaScript the heading
  and steps remain readable; avoid a misleading simultaneous empty message.
- [ ] Verify automatic counts, explicit partial-list counts, zero totals, waiting
  state, dynamic steps, static mode, and disclosure restoration.

## 5 Messages and assistant turns

Current code: [messaging/message.rb](../lib/unmagic/components/messaging/message.rb)
and [ai_chat/message.rb](../lib/unmagic/components/ai_chat/message.rb).
Candidates include `header_element`, `footer_element`, `avatar_cell`, and the
assistant's empty/streaming conditions in `root_attributes` and `body_element`.

Proposed public HTML:

```html
<unmagic-message variant="bubble" own continued>
  <article aria-label="You said">
    <span data-part="author">Keith</span>
    <time data-part="time" datetime="2026-10-02T09:00:00Z">09:00</time>
    <div data-part="body">Can you check this?</div>
    <div data-part="reactions">...</div>
  </article>
</unmagic-message>
```

Contract: retain `bubble`, `row`, `email`, `own`, and `continued`; optional parts
cover avatar, metadata, quote, attachments, reactions, status, actions, and footer.
The inner article preserves native semantics; root IDs remain on the public host.
An assistant specialization can use `<unmagic-ai-message speaker="assistant"
streaming>` with the same article/parts contract. Use `speaker`, not the ARIA
`role` attribute, for user/assistant identity.

- [ ] Prototype CSS grid layout over optional parts and remove header/footer
  wrappers only where they no longer serve layout or native disclosure semantics.
- [ ] Keep `continued` explicit in the first migration. Automatic grouping would
  require author identity, time-gap, and separator rules from the application;
  do not infer identity from a displayed name or compare arbitrary values in CSS.
- [ ] Move continued-avatar presentation into CSS while preserving its column;
  retain Ruby avatar generation, quote links, status formatting, and body escaping.
- [ ] Migrate assistant visibility and thinking indicators after reasoning.
  Preserve IDs, optimistic-template hooks, and the existing streaming markdown
  instance across finalization. Readable body/reasoning controls visibility, not
  generated wrappers or labels.
- [ ] Keep collapsible email/message support on native details/summary. Preserve
  the current summary content restrictions and accessible name; treat excerpt
  generation as a separate decision rather than silently changing its behavior.
- [ ] Verify all three variants, own/continued combinations, attachments/reactions
  arriving later, empty assistant turns, optimistic sends, and final streaming
  replacement without duplicate announcements or lost focus.

## 6 Cards

Current code: [card.rb](../lib/unmagic/components/card.rb), especially
`header_markup` and the body/footer wrappers in `render`.

Proposed public HTML:

```html
<unmagic-card padding="none">
  <h2 data-part="title">Minecraft worlds</h2>
  <div data-part="actions"><a href="/worlds/new">New world</a></div>
  <div data-part="body">...</div>
  <footer data-part="footer">Last updated today</footer>
</unmagic-card>
```

Contract: normal padding by default, `padding="none"` maps to `flush: true`;
`borderless` and `transparent` map to existing options. An optional
`data-part="header"` replaces title/actions, retaining the existing exclusivity
validation. The custom tag is a surface, not an implicit section or link.

- [ ] Use CSS grid and child-presence selectors to place title/actions and apply
  spacing/borders only where relevant. Remove wrappers only when this preserves
  layout; keep an explicit body region for arbitrary content and flush tables.
- [ ] Preserve native `href:` and `tag_name:` behavior through the existing
  renderer initially. Do not replace linked cards with click handlers. Document
  this narrower first migration rather than silently ignoring those options.
- [ ] Keep skeleton content and its accessible loading label server-rendered.
- [ ] Check tabs/panel integration selectors referencing `UnmagicCard__bar` and
  `UnmagicCard__body` before removing classes. Add compatibility selectors during
  opt-in rollout. Add no JavaScript if CSS handles the chosen structure.
- [ ] Verify title-only, actions-only, custom header, footer absent/present, flush
  tables, skeletons, and utility overrides against existing card examples.

## 7 Page headers and sections

Current code: [page_header.rb](../lib/unmagic/components/page_header.rb) and
[section.rb](../lib/unmagic/components/section.rb).
Their nested row/main/heading wrappers mostly encode positioning of optional
content, rather than application decisions.

Proposed public HTML:

```html
<header>
  <unmagic-page-header>
    <h1 data-part="title">Minecraft worlds</h1>
    <p data-part="description">Choose a Bedrock world.</p>
    <div data-part="actions"><a href="/worlds/new">New world</a></div>
  </unmagic-page-header>
</header>
<section>
  <unmagic-section spacing="normal">
    <h2 data-part="title">How to join</h2>
    <div data-part="body"><p>Open Minecraft and add a server.</p></div>
  </unmagic-section>
</section>
```

- [ ] Prototype direct-part CSS grid before adding any JavaScript. Keep native
  header/section/heading structure; retain configurable section heading levels.
- [ ] Define parts for leading content, trailing badges, breadcrumbs/back link,
  section aside, and actions. Preserve the existing breadcrumbs/back exclusivity.
- [ ] Keep `normal`, `tight`, and `none` section spacing. Map page-header `mono`
  to a documented attribute; leave formatted content and skeletons in Ruby.
- [ ] Remove `__row`, `__main`, and `__heading` wrappers only after verifying
  wrapping and alignment for long headings, multiple badges, and mobile actions.
- [ ] Document where helper passthrough attributes land, preserving IDs, labels,
  and utility overrides on the same effective layout box during the transition.
- [ ] Compare markup complexity with the current renderer. If native wrappers
  plus custom tags save no meaningful logic, ship the CSS simplification without
  introducing additional tags.

## Keep in Ruby or defer

| Area | Reason |
|---|---|
| Tables and detail lists | Collection iteration, sort URLs, deferred queries, and formatting are server concerns; preserve native table semantics. |
| Buttons, links, form controls | Existing native controls already provide behavior and semantics; styling alone is insufficient reason to replace them. |
| Payload serialization | Keep `Payload#formatted`, JSON formatting, escaping, and `configuration.code_block` on the server. Header presence can be simplified separately. |
| Workspace trees | Path normalization and folder compaction deserve their own data/API design; do not fold them into the shared panel migration. |
| Permissions and requests | Keep authorization, form submission, and application actions on the server. Their presentation can be evaluated later. |
| Existing behavior elements | Reuse clocks, clipboard, streaming markdown, and optimistic updates rather than rewriting them as part of this work. |

## Completion checklist for each migration

- [ ] Update the component design note, helper documentation, and HTML API docs;
  record fallback behavior, initial semantics, public parts, attributes, and IDs.
- [ ] Add needed modules to `app/assets/javascripts/unmagic/components.js` and
  verify automatic importmap pins, individual imports, and browser export work.
- [ ] Update relevant Ruby specs to verify emitted public content, escaping,
  validation, option passthrough, and compatibility. Test browser behavior where
  responsibility moved out of Ruby instead of asserting only generated wrappers.
- [ ] Extend the existing component-browser catalog examples with both helper
  output and directly authored HTML so neither route gets special treatment.
- [ ] Test content insertion/removal, attribute updates, element moves, snapshot
  clones, Turbo morph/replace/restore, and JavaScript disabled or delayed.
- [ ] Check desktop/mobile, light/dark, reduced motion, forced colors, keyboard
  focus, accessible names, and the component-specific cases listed above.
- [ ] Run relevant specs and lint; rebuild the committed browser stylesheet with
  `bundle exec rake browser:css` when CSS changes.
- [ ] Demo the migration in visible Chrome using Chrome DevTools MCP, with
  screenshots and a recording where practical. Include dynamic updates
  demonstrating the rendering logic that moved into the component.
- [ ] Keep the demo's checks as an end-to-end spec in `spec/e2e/`, not as a
  one-off script (`HEADFUL=1 bundle exec rspec spec/e2e` replays it in a window).

This document only plans work; implementation and browser demos belong to the
individual migration tasks.
