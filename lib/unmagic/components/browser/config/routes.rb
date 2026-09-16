# frozen_string_literal: true

Unmagic::Components::Browser::Engine.routes.draw do
  root to: "pages#overview"
  get "installation", to: "pages#installation"
  get "theming", to: "pages#theming"
  get "components/:slug", to: "pages#component", as: :component

  # What the dialog and toast examples talk to.
  get "dialogs/profile", to: "demos#edit_profile", as: :profile_dialog
  patch "dialogs/profile", to: "demos#update_profile"
  delete "dialogs/profile", to: "demos#destroy_profile"
  get "dialogs/slow", to: "demos#slow_dialog", as: :slow_dialog
  get "dialogs/forbidden", to: "demos#forbidden_dialog", as: :forbidden_dialog
  post "toasts/flash", to: "demos#flash_toast", as: :flash_toast
  post "toasts/stream", to: "demos#stream_toast", as: :stream_toast

  # What the AI chat composer example talks to.
  post "ai_chat/messages", to: "demos#ai_chat_message", as: :ai_chat_messages
  post "ai_chat/stop", to: "demos#ai_chat_stop", as: :ai_chat_stop

  # What the board example talks to.
  patch "board/order", to: "demos#board_order", as: :board_order
  post "board/cards", to: "demos#board_card", as: :board_cards
  post "board/columns", to: "demos#board_column", as: :board_columns
  delete "board", to: "demos#board_reset", as: :board

  # The stylesheet, the components' JavaScript and Turbo, served from the gems
  # themselves. Each URL carries its file's mtime, so it can be cached for good.
  Unmagic::Components::Browser.asset_roots.each do |kind, root|
    mount Rack::Files.new(root.to_s, "cache-control" => "public, max-age=31536000, immutable") => "assets/#{kind}", as: nil
  end

  # The old one-page-per-group URLs. A relative redirect keeps the mount prefix.
  {
    "deferred" => "table", "dialogs" => "dialog", "toasts" => "toast", "primitives" => "card",
    "elements" => "tooltip", "skeletons" => "skeleton", "forms" => "forms"
  }.each do |old, slug|
    get old, to: redirect("components/#{slug}")
  end
end
