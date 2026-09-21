# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :ai_chat_workspace,
  name: "Workspace",
  group: "AI chat",
  helper: "ai_chat_workspace",
  description: "The files an agent has put aside while it works, so you can see what it actually produced. Give " \
               "it paths; it folds them into a tree_view of folders, with a glyph for each kind of file.",
  examples: [
    { key: :files, title: "Files, beside a plan",
      description: "Two sections of one panel, with a divider between them. A file with a url is a link, and " \
                   "its glyph comes from its extension unless icon: says otherwise." },
    { key: :folders, title: "Nested folders and a long path",
      description: "Folders open and fold, and come before the files beside them. A folder that holds only a " \
                   "folder joins it in one row, which shortens from the front so the last folder's name " \
                   "stays; a long file name truncates only when it alone doesn't fit. Each row's title is " \
                   "its full path. The count is the number of files." }
  ]
