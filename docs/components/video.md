# `video_player`, `video_cover`, `video_chapters` and `video_now_playing`

> Status: built
> Tier: 2 (small element)
> Replaces or relates to: the native `<video>` element; `<track kind="chapters">`

## As built

- `video.js` defines `<unmagic-video>`; the chapters and cover are plain
  custom-element names it reads, with no element classes of their own.
  `video_providers.js` holds the native and Stream providers.
- A Stream player with no cover mounts at once, so there's something on
  screen; with a cover it waits for the first play.
- Both examples stream open films from Wikimedia Commons, credited under the
  player as their CC BY 3.0 licences require: Big Buck Bunny in "Chapters",
  and Tears of Steel (2.4:1, so `--unmagic-video-aspect: 12 / 5`) in "Your own
  controls". Each is a VP9 WebM with a QuickTime fallback in a `<video>`
  passed in the block, its cover a frame from the film and its chapters at
  real scene changes. Wikimedia rate-limits clients without a descriptive
  User-Agent, which a browser sends; scripted fetches need one.
- "Your own controls" shows the toggle pattern: each `--toggle` and
  `--toggle-mute` button keeps one name and swaps its icon with Tailwind's
  `group-aria-pressed:`, off the `aria-pressed` the player keeps. The gem's
  Lucide set gains `pause`, `skip-back`, `skip-forward`, `volume-2` and
  `volume-x` for it.
- The asset studio block's walkthrough and the catalog thumbnail play a
  generated clip the browser ships (`assets/videos/tour.mp4`, four 15-second
  coloured segments with a running counter), so `bin/demo-video` checks every
  behaviour above offline, pressing controls it adds for the run; `LIVE=1`
  also plays both films and checks the icon swaps.

## Purpose

A video with chapters, where the page owns every piece of UI. The element
plays the video and knows where it is; everything a person sees or presses
around it (the cover, a chapter list, play buttons, a "now playing" line) is
the page's own markup, pointed at the player. A view reaches for it:
- for a recorded talk or tour with a contents list beside it
- for a video that should cost nothing until someone presses play
- wherever the same chapter UI has to drive more than one kind of video

It is not a set of player controls: the video's own controls (`controls`) do
that. It is the glue between a video and the page around it.

## API

```erb
<%= video_player id: "tour", src: "/tour.mp4", poster: "/still.jpg", chapters: @chapters do %>
  <%= video_cover "tour", image: "/still.jpg", label: "Play the tour", caption: "The tour · 4:40" %>
<% end %>

<%= video_chapters "tour", @chapters %>
<%= video_now_playing "tour" %>
```

| Option | Values | Default | Notes |
|---|---|---|---|
| `id:` | String | — | Required. What controls point at with `commandfor` and `for` |
| `src:` | URL | — | An mp4 (or anything `<video>` plays), or a Stream iframe URL |
| `provider:` | `:native`, `:stream` | `:native` | Validated |
| `chapters:` | Hashes or objects | `[]` | Each answers `start` (seconds or `"1:12"`), `title`, optional `end` |
| `poster:` | URL | `nil` | The still image, as on `<video>` |
| `controls:` | Boolean | `true` | The video's own controls |
| block | markup | — | A `video_cover`, a `<video>` with its own `<source>`s and `<track>`s |

- `video_cover(player_id, image:, label:, caption: nil)` is one cover: a
  button with the image, a play glyph and an optional caption. Any markup
  inside an `<unmagic-video-cover>` works instead.
- `video_chapters(player_id, chapters)` is a list of chapter buttons, each a
  timecode and a title, that marks the playing one.
- `video_now_playing(player_id, label: "Now playing")` is the current chapter's
  title in an `<output>`.

## Markup

```html
<unmagic-video id="tour" class="UnmagicVideo" provider="native" src="/tour.mp4" poster="/still.jpg" controls>
  <unmagic-video-chapter start="0" hidden>Welcome</unmagic-video-chapter>
  <unmagic-video-chapter start="72" hidden>The workshop</unmagic-video-chapter>
  <unmagic-video-cover class="UnmagicVideoCover">
    <button type="button" commandfor="tour" command="--play" aria-label="Play the tour" class="UnmagicVideoCover__button">…</button>
  </unmagic-video-cover>
</unmagic-video>

<ol class="UnmagicVideoChapters">
  <li><button type="button" commandfor="tour" command="--seek" value="72" class="UnmagicVideoChapters__chapter">
    <span class="UnmagicVideoChapters__time">1:12</span> <span class="UnmagicVideoChapters__title">The workshop</span>
  </button></li>
</ol>

<p class="UnmagicVideoNowPlaying">Now playing: <output for="tour" name="chapter"></output></p>
```

- **Chapters are data.** `<unmagic-video-chapter start end>` children render
  nothing (`hidden`, so not even before CSS loads); their text is the title.
  A native `<video>`'s `<track kind="chapters">` is read when there are none.
- **The cover** is whatever is inside `<unmagic-video-cover>`, hidden once
  playback starts.
- **Controls** are buttons using invoker commands: `commandfor` names the
  player, `command` the action, `value` its argument.

## Accessibility

- Controls are real buttons with their own names; the player adds none.
- The player keeps state on its controls: `aria-current="true"` on the chapter
  button playing, `aria-pressed` on toggles.
- `<output>` is a polite live region, so a chapter change is announced. A
  ticking `time` output takes `aria-live="off"`.
- The cover's button is labelled (`label:`). The image inside is `alt=""`.
  While a cover shows, the video or iframe behind it is `inert`, so its own
  controls aren't in the tab order or the accessibility tree out of sight.
- Seeking from a chapter button off screen scrolls the player into view
  (`block: "nearest"`, instant under reduced motion).

## Styling

CSS section: `Video`.

- `UnmagicVideo`: a 16:9 box (`aspect-ratio`, the `--unmagic-video-aspect`
  knob for another shape), `rounded-xl`, `neutral-950` behind the picture. The
  video or iframe fills it.
- `UnmagicVideoCover` fills the box over the video; `__button`, `__image`,
  `__play` (a white disc with a triangle) and `__caption`.
- `UnmagicVideoChapters`: rows of `__time` (mono, tabular) and `__title`;
  `[aria-current="true"]` takes the selected look.
- `UnmagicVideoNowPlaying`: `text-xs text-neutral-500`.
- State attributes on the element (`playing`, `started`, `ended`, `muted`,
  `current-chapter`) are for the page's own CSS.

## Behaviour (JavaScript)

`video.js` defines `<unmagic-video>`; `video_providers.js` holds the native and
Stream providers.

- **Commands** (`command="--…"`, argument in `value`): `--play`, `--pause`,
  `--toggle`, `--seek` (seconds or `m:ss`; plays), `--skip` (±seconds),
  `--chapter` (index), `--next-chapter`, `--previous-chapter`, `--mute`,
  `--unmute`, `--toggle-mute`, `--rate`, `--fullscreen`. Browsers without
  invoker commands get the same through one delegated click listener.
- **Providers:** `native` uses the `<video>` inside, or builds one from `src`.
  `stream` builds the Stream iframe on first play (cued with `startTime` and
  `autoplay`) and talks to it with the iframe's postMessage protocol; a seek
  the iframe doesn't answer rebuilds it cued at that time.
- **State:** attributes on the element; `aria-current`/`aria-pressed` on every
  `[commandfor]` control; `<output for name>` values `chapter`,
  `chapter-index`, `time`, `duration`, `remaining`.
- **API:** `play()`, `pause()`, `seek(seconds)`, `currentTime`, `duration`,
  `paused`, `muted`, `chapters` (settable), `currentChapter`.
- **Events** (bubble): `unmagic-video:ready` `{ duration }`,
  `unmagic-video:play` `{ first }`, `unmagic-video:pause`,
  `unmagic-video:ended`, `unmagic-video:timeupdate` `{ currentTime }`,
  `unmagic-video:chapterchange` `{ chapter, previous }`,
  `unmagic-video:error` `{ message }`.
- **Turbo:** chapters and controls are re-read when the page morphs or
  renders, and a chapter streamed in is picked up by a MutationObserver.

## I18n

| Key | Default |
|---|---|
| `unmagic.components.video.now_playing` | "Now playing" |
| `unmagic.components.video.chapters` | "Chapters" |

## Specs

`spec/unmagic/components/video_spec.rb`: the element's attributes, chapter
children (escaped titles, `"1:12"` and objects), the cover, the chapter list's
commands, the output, and `ArgumentError` for a bad provider.

## Preview

A native video with chapters, cover, chapter list and now-playing line; a
custom control bar built only from command buttons and outputs.

## Open questions

- **A YouTube provider** for videos played straight from YouTube.
