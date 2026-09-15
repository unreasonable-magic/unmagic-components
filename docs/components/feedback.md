# `feedback_form`

> Status: draft
> Tier: marketing (arguably app UI; core CSS either way)
> Replaces or relates to: Rails Blocks "Feedback" (gap source). Composes `FormBuilder`, `button_classes`, `autogrow_text_area` and `dialog_tag`/`popover`.

## Purpose

A small "How was this?" form: a rating (thumbs up/down, or 1–5 faces or stars),
an optional comment, and a submit button. It posts to a URL the host owns. Use
it at the foot of a docs page, after a completed flow, or behind a "Feedback"
button.

The gem renders the form. It doesn't store anything and ships no controller.

**Placement:** a core `Feedback` section in `components.css`. It lives inside
applications (docs, settings, post-checkout), and it's built from form controls
the gem styles. Placement is decided: marketing-style components live in the
core stylesheet.

## API

```erb
<%= feedback_form url: feedback_path, scale: :thumbs, prompt: "Was this page helpful?" do |form| %>
  <%= form.hidden_field :page, value: request.path %>
<% end %>

<%= feedback_form url: feedback_path, scale: :five, comment: :required, model: Feedback.new %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `url:` | path | required | Passed to `form_with` |
| `model:` | record | none | Passed to `form_with`, for error display |
| `scale:` | `:thumbs`, `:faces`, `:five` | `:thumbs` | Validated |
| `prompt:` | string | I18n | The legend |
| `comment:` | `:optional`, `:required`, `false` | `:optional` | Validated |
| `field:` | symbol | `:rating` | The rating param name; the comment is `:comment` |

- The block is yielded the `FormBuilder`, for extra hidden fields.
- Other options go on the `<form>`.

## Markup

```html
<form class="UnmagicFeedback" action="/feedback" method="post" data-unmagic-feedback>
  <fieldset class="UnmagicFeedback__rating">
    <legend class="UnmagicLabel">Was this page helpful?</legend>
    <label class="UnmagicFeedback__choice">
      <input type="radio" name="feedback[rating]" value="up" class="UnmagicVisuallyHidden">
      <svg class="UnmagicIcon" aria-hidden="true">…thumbs-up…</svg>
      <span class="UnmagicVisuallyHidden">Yes</span>
    </label>
    …
  </fieldset>
  <div class="UnmagicField UnmagicFeedback__comment">
    <label class="UnmagicLabel" for="feedback_comment">Anything else?</label>
    <unmagic-autogrow class="UnmagicAutogrow"><textarea class="UnmagicInput" id="feedback_comment" name="feedback[comment]" rows="2"></textarea></unmagic-autogrow>
  </div>
  <button type="submit" class="UnmagicButton UnmagicButton--primary UnmagicButton--small" data-turbo-submits-with="Sending…">Send</button>
</form>
```

- **The rating is a native radio group**, so arrow keys, required validation
  and no-JS submission all come free.
- **The comment is hidden until a rating is chosen.** CSS does this with
  `:has(:checked)` on the form, so no script is needed.

## Accessibility

- A `fieldset` and `legend` name the group. Each radio has a visually hidden
  text label ("Yes"/"No", "1 star"…), and its icon is `aria-hidden`.
- The focus ring is drawn on the choice using `:has(:focus-visible)`.
- A server response shows success with the existing toast
  (`turbo_stream.toast`) or by replacing the form. The note recommends the host
  answers with a stream that replaces the form with a "Thanks" message.
- `errors_summary` and field errors come from `FormBuilder` when `model:` is
  given.

## Styling

- **Section:** `Feedback`.
- **Elements:** `__rating`, `__choice`, `__comment`, `__thanks`.
- **Selected state:** `.UnmagicFeedback__choice:has(:checked)` uses `accent`
  and `surface-3`.
- **Five-star scale:** fills up to the checked one with
  `:has(~ :checked)` sibling logic on reversed DOM order, and uses the
  `--unmagic-rating` theme token (accepted, shared with `testimonial`), falling
  back to `--color-amber-400, #fbbf24`. It goes in the README Theming list and
  in the preview layout's dark block.
- **Comment reveal:** `.UnmagicFeedback:not(:has(.UnmagicFeedback__rating :checked)) .UnmagicFeedback__comment { display: none }`.
- **Controls:** the comment textarea is styled by the gem through
  `config.control_class` (`:text_area`, giving `UnmagicInput`), like every
  builder control.
  - The rating radios are visually hidden, so their look comes entirely from
    `__choice`. They don't take `UnmagicRadio`.
  - A host that returns `nil` from the seam gets an unstyled textarea, and the
    rest of the form is unchanged.
- **Motion:** a 150ms fade-in on reveal, off under reduced motion.

## Behaviour (JavaScript)

_None beyond the existing `autogrow`._ The submitting label comes from
`FormBuilder#submit`.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.feedback.prompt` | "Was this helpful?" |
| `unmagic.components.feedback.comment` | "Anything else?" |
| `unmagic.components.feedback.submit` | "Send" |
| `unmagic.components.feedback.up` / `.down` | "Yes" / "No" |
| `unmagic.components.feedback.stars` | "%{count} out of 5" |
| `unmagic.components.feedback.thanks` | "Thanks for the feedback." |

## Specs

- The form posts to `url:`, with a fieldset and legend.
- Radio count per scale is 2, 3 or 5, with the right values and hidden labels.
- `comment: false` omits the textarea; `:required` adds `required`.
- The block's hidden field is present.
- `ArgumentError` for an unknown `scale:` or `comment:`.
- Model errors render.

## Preview

- **Page:** `marketing` (or `primitives`), showing all three scales. It posts
  to a preview action answering with a toast stream.
- **Hand-check:**
  - Keyboard arrows within the rating.
  - The comment appears after a rating is chosen.
  - Submit shows "Sending…".
  - Dark mode.

## Open questions

- Should it ship a `feedback_thanks` helper for the replacement markup?
- Should it also come as a "Feedback" button that opens this in a popover?
