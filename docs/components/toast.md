# Toast

Expand the existing Rails toast API and component-browser examples using the
capabilities demonstrated by https://www.reshaped.so/docs/components/toast as a
checklist. Implement the markup and behaviour in this library's own conventions.

See [JavaScript toast API](toast_javascript_api.md) for client-side creation,
updates, actions and events using these same mounts.

## API

Keep `flash_toasts` and `turbo_stream.toast(message, tone: :good)` compatible.
Add per-toast `duration:` (milliseconds, 0 means manual dismissal), `position:`
(`top_start`, `top`, `top_end`, `bottom_start`, `bottom`, `bottom_end`),
`width:` (`short`, `long`, or positive pixel integer), `title:`, `icon:`
(a bundled icon or false), and `layout:` (`horizontal` or `vertical`).
Keep the existing four tones and add `neutral`, `accent`, and `inverted`.
Defaults remain five seconds, top end, short width and the tone's icon.

A stream block yields a builder with `leading`, `actions` and `body` capture
slots. Leading content replaces the default icon; an explicit icon takes
precedence. Body replaces the standard title/message layout. Actions use normal
Rails buttons/links/forms. `data-unmagic-toast-dismiss` also works on an action.
Default `UnmagicButton` actions inherit the toast text colour, with a subtle
current-colour fill, border, hover and focus ring. Explicit button variants
remain unchanged. `close_button: true` retains the labelled close button by
default; `false` omits it without changing timers or custom dismiss actions.
Sticky toasts without the × should supply a custom dismiss action. Extra HTML attributes reach its
root. `target:` selects a mount, defaulting to `unmagic_toasts`.

`flash_toasts` gains `id:`, `position:` and `scoped:`. A scoped mount stays inside
its nearest positioned ancestor rather than entering the top layer. Render six
permanent stacks so independently positioned notifications survive Turbo visits.
Persist each resolved duration on its toast so moving or restoring a stack never
turns a sticky notification into a timed one.

## Accessibility and behaviour

Keep polite live regions and alert roles for errors. Pause timers on hover or
focus; never steal focus on arrival. Restore focus to the triggering control
when a focused toast is dismissed, if the control is still connected. All close
buttons have translated accessible names. Keep the existing modal limitation:
viewport toasts are raised above dialogs when they open, but remain inert until
the dialog closes.
Validate enumerations and numeric options in Ruby. Escape plain text and capture
custom markup through Rails. No client-side HTML-string API.

## Small screens

Widths clamp to the containing region. The text and actions share a column
between the icon and close button. Horizontal groups move below the text when
they cannot fit beside a 12rem text column; vertical actions always align with
the text below it. Long text and action rows wrap. Close
controls meet 44px touch targets. Positions use logical start/end for RTL.
Use existing palette colours, dark variants and reduced-motion rules.

## Examples and verification

Retain flash, stream and above-dialog examples. Add title/icon/action, all tones,
six positions, short/long/custom durations including sticky, widths, horizontal
and vertical actions, avatar leading content, a custom announcement layout, and
panel boundaries. Browser examples post to the demo endpoint; richer responses
live in matching Turbo Stream partials shown in each Code tab.

RSpec covers rendering, validation, escaping, slots, stream targeting and scoped
mounts. A replayable visible-browser demo checks timed versus sticky behaviour,
manual/keyboard dismissal, positions, widths, action layouts, panel containment,
Turbo navigation, light/dark and phone layouts, and captures screenshots.
