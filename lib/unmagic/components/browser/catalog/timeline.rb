# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :timeline,
  name: "Timeline",
  group: "Data display",
  helper: "timeline",
  import: nil,
  new: true,
  description: "Things that happened, in order, joined by a line: an audit log, an order's history, a deploy " \
               "log, an activity feed, a roadmap. An ordered list with no script.",
  examples: [
    { key: :basic, title: "Dots and times", layout: :full,
      description: "The common case. time: goes through local_time_tag, so time_format: :relative keeps itself current." },
    { key: :order, title: "Order status", layout: :full,
      description: "icon: in a circle, tone: to colour it, and pending: true for what hasn't happened yet: " \
                   "a hollow marker and a dashed line into it. A string time prints as it is." },
    { key: :activity, title: "Activity feed", layout: :full,
      description: "avatar: takes a name (or avatar options) and draws it small. The block is the event's body." },
    { key: :deploys, title: "Deploy log", layout: :full,
      description: "A failed step carries its log in the body; anything goes there, a code view included." },
    { key: :commits, title: "Commits", layout: :full,
      description: "href: links the title. Built from a loop, in the order given; the gem doesn't sort." },
    { key: :roadmap, title: "Roadmap, horizontal", layout: :full,
      description: "orientation: :horizontal lays events side by side from 40rem, and falls back to vertical " \
                   "on a phone." },
    { key: :releases, title: "Releases, horizontal with dates", layout: :full,
      description: "A Date reads as a date. Dots keep a horizontal timeline light." },
    { key: :tones, title: "Tones", layout: :full,
      description: "Every tone on a dot and on an icon. Markers are decoration: the title says what happened." },
    { key: :mixed, title: "Mixed markers", layout: :full,
      description: "Dots, icons and avatars share one column, so the line stays straight." },
    { key: :interview, title: "Interview process", layout: :full,
      description: "marker: :decimal puts each step's position in its marker, named as CSS's list-style-type. The time can be markup, a badge " \
                   "here, and the body holds cards, people and links." },
    { key: :actions, title: "Actions in the body", layout: :full,
      description: "A pending step can carry the buttons that move it along." },
    { key: :long, title: "Long titles",
      description: "Titles and descriptions wrap; the time drops under the title when there's no room." },
    { key: :loading, title: "Loading and empty", layout: :full,
      description: "skeleton: true stands three placeholder events in. With no events a timeline renders " \
                   "nothing, so .presence || empty_state fills the gap." }
  ]
