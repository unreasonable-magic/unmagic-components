# `text_highlights`

> Status: built
> Tier: 1 (no JS)
> Replaces or relates to: Rails' `highlight` (search terms, every occurrence,
> one colour); `message`, whose `m.highlight` part uses it

## Purpose

Marking what matters in a text someone else wrote, the way a highlighter pen
does: a word, a sentence, or a passage from one quote to another, in a colour
of the caller's choosing. The case it was built for is quoting a message in a
document and pointing at what the sender said. It is **not** for search
results (Rails' `highlight` marks every occurrence of a term) or for colouring
source (`code_view`).

## API

```erb
<%= text_highlights message.body, "pick them up at 5" %>

<%= text_highlights message.body, [
      "pick them up",
      { text: "not before Friday", color: :red },
      { from: "I can't", to: "this week", color: :blue }
    ] %>

<%= text_highlights [ "Friday" ] do %>
  <%= Markdown.render(note.body) %>
<% end %>
```

| Key | Values | Default | Notes |
|---|---|---|---|
| `text:` | string | — | The passage. A bare string is `{ text: string }` |
| `from:`, `to:` | strings | — | A range: the first `from:`, through the first `to:` after it |
| `color:` | `:yellow`, `:green`, `:blue`, `:pink`, `:red` | `:yellow` | Validated; raises `ArgumentError` |

- `text:` and a range are exclusive; one of them is required.
- A highlight is found by what it says, not where it is, so a highlight written
  by hand or by a model survives the text being re-rendered. Matching folds
  case, collapses whitespace (block edges count as whitespace), and treats
  curly and straight quotes, dashes and hyphens, and an ellipsis and three dots
  as the same.
- The first match wins, as with a URL's text fragment (`#:~:text=`). Quote
  more to reach a later occurrence.
- Overlapping highlights: the later one in the list wins where they overlap.
- A highlight that isn't found marks nothing; `TextHighlights#unmatched` lists
  them after `render`, for a host that wants to tell its author.
- Blank content renders an empty string; no highlights returns the content
  (escaped, if it was plain text).

## Markup

```html
I'll <mark class="UnmagicMark UnmagicMark--yellow" data-highlight="0">pick them up at 5</mark>,
<mark class="UnmagicMark UnmagicMark--red" data-highlight="1">not before Friday</mark>.
```

`<mark>` is the native element for exactly this: text marked for its relevance
in another context. It is rendered on the server, so it shows without script,
in print, in a Turbo snapshot and through a morph. HTML content is parsed with
Nokogiri and its text nodes split; a highlight that crosses a tag becomes one
`<mark>` per piece, sharing `data-highlight`.

The CSS Custom Highlight API was the other candidate. It paints ranges without
touching the DOM, but needs script to build the ranges, shows nothing until it
runs, isn't exposed to assistive tech, and doesn't reach a PDF or an email a
host renders from the same text. The API's shape (named highlights over ranges)
is kept; the mechanism is markup.

## Accessibility

- `<mark>` maps to the `mark` role; screen readers that announce it say so.
- Colour is the author's own distinction, not the component's; the mark itself
  says "highlighted" without colour.
- Under forced colours the marks use the system's `Mark` and `MarkText`.

## Styling

- Section `Highlights` in `engine.css`: `UnmagicMark` and the modifiers
  `--yellow`, `--green`, `--blue`, `--pink`, `--red`.
- An opaque pen colour (`-200`, `dark:` `-300`) with `neutral-950` ink in both
  themes, so a mark reads on a white page, a dark page and a dark own bubble.
- `box-decoration-break: clone` so each line of a wrapped mark is rounded.
- `print-color-adjust: exact` so marks print.

## Behaviour (JavaScript)

_None: markup and CSS only._

## I18n

None: it prints no words of its own.

## Specs

`spec/unmagic/components/text_highlights_spec.rb`: plain text escaping, the
folding rules, first match, ranges, overlaps, markup kept and crossed, blank
input, `unmatched`, `ArgumentError` for each malformed highlight, and the
`message` part.

## Preview

- Data display → Text highlights: colours, ranges, and a highlight across a
  link and a paragraph break. Messaging → Message → Highlighted passages, and
  the Team inbox block.
- Check by hand: dark theme, an own bubble, a wrapped mark, print preview.
