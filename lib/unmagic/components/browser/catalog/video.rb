# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :video,
  name: "Video",
  group: "Data display",
  helper: "video_player",
  import: "unmagic/components/video",
  new: true,
  description: "A video the page drives with its own controls. It has no UI of its own: buttons anywhere point at " \
               "it with invoker commands (commandfor and command), and <output>s show where it is. Chapters are " \
               "data inside it, and it marks the chapter playing on every control that seeks to it.",
  examples: [
    { key: :chapters, title: "Chapters",
      description: "An open film streamed from Wikimedia Commons, in a <video> of your own with two sources. " \
                   "video_cover covers it until it plays, video_chapters lists the chapters as seek buttons, and " \
                   "video_now_playing names the one playing. Press a chapter before playing to start there." },
    { key: :controls, title: "Your own controls",
      description: "controls: false, and a control bar of plain buttons and outputs. The player keeps " \
                   "aria-pressed on --toggle and --toggle-mute, so the play and mute buttons swap their icons " \
                   "with Tailwind's group-aria-pressed: variant and no script. A 2.4:1 film, shaped by the " \
                   "--unmagic-video-aspect knob." }
  ]
