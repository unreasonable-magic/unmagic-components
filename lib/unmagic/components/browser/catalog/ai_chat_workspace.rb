# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_workspace,
  name: "Workspace",
  group: "AI chat",
  helper: "ai_chat_workspace",
  description: "The files an agent has put aside while it works, so you can see what it actually produced. A flat " \
               "list of paths for now; a nested tree waits on the gem's tree view.",
  examples: [
    { key: :files, title: "Files, beside a plan",
      description: "Two sections of one panel, with a divider between them. A file with a url is a link." },
    { key: :warm_greys, title: "In a host's warm greys",
      description: "The same panel with Tailwind's neutral ramp redefined on its wrapper, so its text, borders and " \
                   "surfaces share one warm palette. Each shade keeps neutral's lightness, so contrast holds in " \
                   "light and dark. Nothing else on the page changes." }
  ]
