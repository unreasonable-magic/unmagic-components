# frozen_string_literal: true

module Unmagic
  module Components
    module Browser
      # Composed pages, kept separate from the individual component catalog.
      module BlockCatalog
        Block = Data.define(:slug, :name, :description, :category, :components)

        BLOCKS = [
          Block.new(slug: "workspace", name: "Workspace overview",
            description: "A workspace dashboard with activity, project progress and a team snapshot.",
            category: "Dashboards", components: %w[navbar page_header card chart progress table avatar badge]),
          Block.new(slug: "team", name: "Team directory",
            description: "A people page with member cards, roles and a shared team directory.",
            category: "People", components: %w[navbar page_header card avatar badge table]),
          Block.new(slug: "login", name: "Welcome back", description: "A focused sign-in page with email and password fields.",
            category: "Authentication", components: %w[card forms button]),
          Block.new(slug: "signup", name: "Create an account", description: "A split signup page with a welcoming introduction and account form.",
            category: "Authentication", components: %w[forms button]),
          Block.new(slug: "sidebar", name: "Sidebar workspace", description: "An application shell with grouped navigation and a sidebar that becomes a mobile drawer.",
            category: "Application shell", components: %w[sidebar page_header card table badge avatar]),
          Block.new(slug: "profile_settings", name: "Profile settings", description: "An editable profile with personal details, time zone and a short bio.",
            category: "Settings", components: %w[navbar avatar page_header card forms badge button]),
          Block.new(slug: "billing_settings", name: "Plan and billing", description: "Subscription details, seat and storage usage, and an invoice history.",
            category: "Settings", components: %w[navbar avatar page_header card detail_list progress table badge]),
          Block.new(slug: "notifications_settings", name: "Notification preferences", description: "Email subscriptions, delivery schedules and quiet hours.",
            category: "Settings", components: %w[navbar avatar page_header card forms button]),
          Block.new(slug: "analytics", name: "Audience analytics", description: "Visitor metrics, a comparison chart, acquisition channels and popular pages.",
            category: "Dashboards", components: %w[navbar avatar page_header card chart progress table badge]),
          Block.new(slug: "sales", name: "Sales dashboard", description: "Revenue metrics, weekly sales, recent orders and bestselling products.",
            category: "Dashboards", components: %w[navbar avatar page_header card chart table badge]),
          Block.new(slug: "password_recovery", name: "Password recovery", description: "A simple email form to help people recover access to their workspace.",
            category: "Authentication", components: %w[card forms button]),
          Block.new(slug: "not_found", name: "Page not found", description: "A friendly 404 page with a route home and expandable help.",
            category: "Shared pages", components: %w[card button]),
          Block.new(slug: "project_planner", name: "Project planner", description: "A sortable sprint board, prioritized backlog and quick navigation.",
            category: "Project work", components: %w[breadcrumbs combobox command_palette kbd tooltip menu section board sortable_list toggle page_header card badge avatar]),
          Block.new(slug: "asset_studio", name: "Asset studio", description: "Inspect, crop and sample artwork alongside its details and related files.",
            category: "Creative tools", components: %w[image_zoom image_crop image_color_picker tabs copy_button item empty_state section card detail_list avatar page_header]),
          Block.new(slug: "release_monitor", name: "Release monitor", description: "Build logs, release notes, rollout activity and pending health metrics.",
            category: "Developer tools", components: %w[callout spinner separator elapsed local_time panel code_view scroll_area streaming_markdown skeleton tree_view timeline disclosure card page_header]),
          Block.new(slug: "customer_workspace", name: "Customer workspace", description: "Account details, paginated contacts, notes and contextual actions.",
            category: "People", components: %w[popover dialog confirm toast context_menu pagination table detail_list card button avatar page_header]),
          Block.new(slug: "assistant_workspace", name: "Research assistant", description: "A conversation with sources, slash commands, a composer, plan and files.",
            category: "AI workspaces", components: %w[ai_chat ai_chat_message ai_chat_reasoning ai_chat_tool_call message_attachments ai_chat_citation message_actions ai_chat_welcome ai_chat_composer ai_chat_slash_menu ai_chat_plan ai_chat_workspace tabs page_header]),
          Block.new(slug: "assistant_review", name: "Agent review", description: "Review an agent run with recorded decisions, permissions, drafts and diagnostics.",
            category: "AI workspaces", components: %w[ai_chat_request ai_chat_permission ai_chat_proposal ai_chat_branch_picker ai_chat_failure ai_chat_payload tabs card detail_list page_header]),
          Block.new(slug: "team_inbox", name: "Team inbox", description: "A candidate's email thread beside the team's channel about it, with reactions, actions and someone typing.",
            category: "Messaging", components: %w[message_thread message message_actions message_attachments message_reactions message_separator message_typing navbar page_header card avatar badge])
        ].freeze

        def self.all = BLOCKS
        def self.for_component(slug) = all.select { |block| block.components.include?(slug.to_s) }
        def self.uncovered_components = Catalog.all.reject { |component| for_component(component.slug).any? }
        def self.grouped = all.group_by(&:category)
        def self.find(slug) = all.find { |block| block.slug == slug }
      end
    end
  end
end
