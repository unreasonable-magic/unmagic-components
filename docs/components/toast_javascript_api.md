# JavaScript toast API

Status: implemented. See the README Toasts section.

Related: [Toast](toast.md). Extend the existing toast system so client-side
operations can report results without a server round trip. Rails flashes,
Turbo Stream toasts, and JavaScript toasts share the same mounts and behaviour.

## Public API

```js
import { toast } from "unmagic/components/toasts";

const id = toast.show("Copied to clipboard.");
toast.dismiss(id);

const upload = toast.show("Uploading…", { duration: 0 });
toast.update(upload, {
  message: "Upload complete.",
  tone: "good",
  duration: 5000,
});

toast.dismissAll(); // Default mount only.
```

`show(message, options)` returns an opaque string id synchronously.
`update(id, patch)` returns true if an active toast was updated, otherwise false.
`dismiss(id)` returns true if dismissal started, otherwise false; repeated calls
are harmless. `dismissAll({ target = "unmagic_toasts" } = {})` returns the number
of toasts whose dismissal started in that mount. Removal uses the existing exit
animation. Updating a toast that is leaving does not revive it.

Expose the same operations on `<unmagic-toasts>` instances. Instance methods are
scoped to that mount; the module facade resolves the current mount at call time,
so callers do not have to retain DOM references across Turbo navigation.

No window global, automatic mount insertion, or implicit network requests.
The app renders `flash_toasts` and imports the module before calling the API.
A missing mount or invalid options throws a descriptive error. Unknown or
expired toast ids are ordinary no-ops for update/dismiss.

## Options

Use camelCase for JavaScript keys and preserve Ruby's enum values.

| Option | Default | Meaning |
| --- | --- | --- |
| `title` | none | Plain text above the message |
| `tone` | `"good"` | Existing seven tones |
| `duration` | mount default | Milliseconds; `0` is sticky |
| `position` | mount default | Existing six values, e.g. `"bottom_end"` |
| `width` | `"short"` | `"short"`, `"long"`, or positive integer pixels |
| `layout` | `"horizontal"` | Existing horizontal/vertical layouts |
| `closeButton` | `true` | Show the built-in × |
| `icon` | tone icon | `false` hides it; custom icon names deferred |
| `actions` | `[]` | Action descriptors, described below |
| `id` | generated | Optional app-supplied stable identifier |
| `target` | `"unmagic_toasts"` | Mount id, including a scoped panel |

Require string text, valid enums, finite nonnegative durations, positive pixel
widths, and boolean flags. At least one of message/title must contain text.
`show` with an already-active id throws; use `update` explicitly. Ids are logical
toast identifiers, distinct from arbitrary HTML ids and unique across mounts.
No arbitrary HTML attributes or style strings in this first JavaScript API.

```js
const id = toast.show("Project saved.", {
  target: "project_toasts",
  position: "bottom_end",
  closeButton: false,
  duration: 2500,
});
```

## Actions

```js
toast.show("Item archived.", {
  duration: 0,
  closeButton: false,
  actions: [
    { label: "Undo", onClick: async () => restoreItem() },
    { label: "Dismiss" },
  ],
});
```

An action has a plain-text `label`, optional `onClick({ id })`, and
`dismiss: true` by default. With no callback it simply dismisses the toast.
`dismiss: false` keeps it open after the callback succeeds.

Await promise-returning callbacks. While pending, disable that action against
duplicate activation and hold the toast's countdown. Manual dismissal through
other controls is still allowed; late callback completion never resurrects a
removed toast. On rejection, leave the toast visible, re-enable the action, resume
the remaining countdown and emit `unmagic-toast:action-error` with `{ id, error }`.
Do not silently turn a rejected action into a success dismissal. Applications
own error messaging and server effects; a label such as Undo does nothing by
itself. Standard action styling inherits the toast tone.

With `duration: 0` and `closeButton: false`, the caller supplies a dismiss action
or dismisses/updates it programmatically. Document this without attempting to
infer callback behaviour or inventing a mandatory timeout.

## Update and timer semantics

- A patch changes only supplied fields. `message` is allowed in the patch;
  title can be cleared with null and actions with an empty array.
- Omitted duration preserves remaining time, including a paused timer. A new
  duration resets the countdown; zero cancels it. Hover, focus, or an in-flight
  action keeps a new countdown paused until the hold ends.
- Omitted properties keep their resolved values, even if mount defaults change.
- Tone changes update the default icon and alert semantics. `icon: false` stays
  hidden until explicitly reset to the default with `icon: null`.
- Position changes move the same toast between regions in its current mount.
  Changing target or id through update is not supported.
- Update only the parts that changed. Preserve focus in unchanged controls; if
  a focused action is removed, move focus to a remaining close/dismiss control
  or the original trigger when still connected. Do not steal focus on arrival.

## Rails interoperability and implementation boundaries

1. Add an inert, Ruby-rendered blueprint to each mount, including the standard
   content slots, action button prototype, translated close label and tone icons.
   Reuse the Ruby rendering code; JavaScript clones the blueprint and fills text
   with `textContent`, avoiding a second handwritten HTML implementation.
2. Extract one insertion/removal/update path in `toasts.js`. Template consumption
   and public methods use the same region routing, animations, timer/hold state,
   focus handling, and lifecycle events.
3. Track toast identity separately from DOM ids. Add an optional `toast_id:` to
   `turbo_stream.toast` so an app can address a server-created toast in JavaScript.
   Keep existing `id:` as the root HTML attribute for compatibility. Assign logical
   ids to unaddressed incoming templates too. Define the same duplicate-id rule
   for stream delivery; reject and report a collision without replacing content.
4. Keep action callbacks in a module registry keyed by logical id. They survive
   permanent-node moves and morphs; clean them up on dismissal or actual removal
   of their mount. Distinguish a Turbo move from permanent disconnection.
5. Reconcile cached clones with the active registry. A Back/Forward snapshot must
   not resurrect an expired JS toast or restore a callback-less action. Preserve
   active permanent toasts; discard stale JS snapshots without registry entries.
   Verify this against real Turbo navigation before considering v1 complete.
6. Use the same 0-duration, reduced-motion, logical position, scoped-boundary,
   responsive layout and modal behaviour as existing toasts. Ordinary API calls
   need no Turbo; Turbo support is required when the host uses navigation/streams.

Lifecycle events bubble from the mount: `unmagic-toast:show`,
`unmagic-toast:update`, and `unmagic-toast:dismiss`. Each includes `{ id }`;
dismiss also includes `reason: "timeout" | "close" | "action" | "api"` and fires
once when dismissal starts. Removing a mount during navigation is cleanup, not
a user dismissal. Programmatic dismissal can address either a JS toast or a
server toast with a known logical id.

## Defer beyond v1

- `toast.promise`, built-in loading/progress states, and tone shorthand methods.
- Arbitrary HTML strings, custom body/leading DOM slots, and custom icon names.
  Existing Rails builders continue to cover rich compositions; consider a
  server-rendered template entry point separately if client-side reuse is needed.
- Global configuration, automatic mounts, queues/limits, swipe gestures, and
  deduplication/upsert behaviour. These are independent of a callable toast API.

## Delivery and verification

Implement the shared lifecycle and blueprint first, then public methods and
updates, then actions and Rails identity. Add browser examples for client-only
show/dismiss, sticky-to-success updates, scoped targets, custom dismissal without
an ×, action rejection, and a Rails-created toast dismissed from JavaScript.

Ruby specs cover the blueprint, translations, default compatibility, and logical
ids. Browser verification covered the public contract, invalid
options, no raw-HTML interpretation, remaining/reset timers, overlapping holds,
async actions, id collisions, events, focus, Turbo visits/morphs/cache restores,
scoped mounts, light/dark, phone widths and reduced motion.

Async actions and updates are included. Custom JavaScript content rendering
remains a separate follow-up. Viewport toasts are re-raised when a native dialog
opens, keeping existing notifications above its backdrop.
