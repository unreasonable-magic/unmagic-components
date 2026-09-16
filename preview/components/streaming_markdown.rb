# frozen_string_literal: true

ComponentsPreview::Catalog.component :streaming_markdown,
  name: "Streaming Markdown",
  group: "AI chat",
  helper: "streaming_markdown_tag",
  import: "unmagic/components/streaming_markdown",
  description: "Server-rendered HTML revealed at a steady pace as fuller renders of it arrive, so a reply reads as " \
               "one smooth stream rather than the bursts it lands in. Parsing stays on the server; the element only " \
               "reveals.",
  examples: [
    { key: :reveal, title: "A reply arriving in bursts", layout: :full,
      description: "Press Play: the renders arrive unevenly, the reveal doesn't. Lists never flicker as they grow. " \
                   "Under reduced motion each render paints at once." },
    { key: :stopped, title: "Stopped mid-reply", layout: :full,
      description: "Stop swaps in a final element, and every flush still on its way is refused." }
  ]
