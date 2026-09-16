# frozen_string_literal: true

module Unmagic
  module Components
    # Mixed into ActionView by the engine, so every template can call these.
    module ActionViewHelpers
      # Declarative tables in the spirit of form_for: table_for yields a builder
      # that collects column definitions, then renders the table chrome — the
      # card, header (with optional sort links), empty state, and pagination — so
      # index views only describe their cells.
      #
      #   <%= table_for @users do |table| %>
      #     <% table.empty "No team members yet." %>
      #     <% table.column "Name" do |user| %>
      #       <%= user.name %>
      #     <% end %>
      #     <% table.column "Created", sort: :created_at, direction: :desc do |user| %>
      #       <%= user.created_at.to_fs(:short) %>
      #     <% end %>
      #     <% table.column "Actions", align: :right do |user| %>
      #       <%= button_to "Remove", user_path(user), method: :delete %>
      #     <% end %>
      #   <% end %>
      #
      # Linking to a record is the view's job — render the cell's primary text as
      # a link.
      #
      # sort:  a column with sort: renders its header as a link that toggles
      #        ?sort/?direction; direction: declares the column's first direction.
      #        Pass sorted_by:/sort_direction: when the applied default isn't in
      #        params, and sort_url: ->(key, direction) { url } when sorting is
      #        carried by other params (e.g. nested search params).
      # defer: true wraps the table in a turbo frame pointing back at the current
      #        URL: the initial request renders only a skeleton — the collection
      #        is never touched — and the frame then fetches the real rows.
      #        Sorting and paging navigate within the frame, advancing the URL.
      #        Pairs with a lazy collection so the skeleton render costs nothing;
      #        the action needs no special casing.
      # width: pins a column through a <colgroup>, switching the table to a fixed
      #        layout. A CSS length ("40%", "170px") rides on the <col> as a
      #        style; anything else is used as a class name, so a Tailwind host
      #        can pass "w-[40%]". Give every column of a deferred table a width
      #        so the skeleton and the rows that replace it lay out identically.
      #
      # Empty states come in two flavours. table.empty is the blank slate for a
      # genuinely empty dataset; table.no_results is shown instead when a
      # search/filter matched nothing. The table tells them apart on its own: a
      # collection reporting filtered? picks no_results automatically. A plain
      # relation or array isn't filterable, so it always uses empty.
      #
      # Pagination renders through the configured pagination seam, from whatever
      # the configured pagy_for seam resolves (paginate: false to suppress, or
      # pass a pagy object directly).
      #
      # Any other option rides on the <table> itself — class:, data:, aria — so a
      # view can space or annotate it without a wrapper. `id:` is the exception:
      # it names the deferred turbo frame, not the table.
      def table_for(collection, defer: false, id: nil, paginate: true, columns: nil, **options, &block)
        builder = Components::Table.new(self, collection, **options)
        render(columns, table: builder) if columns
        capture(builder, &block) if block

        pagy = table_pagy_for(collection, paginate)

        if defer
          frame_id = id || "#{controller.controller_name}_table"

          if turbo_frame_request_id == frame_id
            turbo_frame_tag frame_id, target: "_top" do
              builder.render(pagy: pagy, turbo_frame: frame_id)
            end
          else
            turbo_frame_tag frame_id, src: request.original_url, target: "_top" do
              builder.skeleton
            end
          end
        else
          builder.render(pagy: pagy)
        end
      end

      # The single <tr> a table would render for one record — what a Turbo Stream
      # broadcast upserts into a live table's tbody.
      #
      # The columns have to be declared somewhere both the table and the broadcast
      # can reach, so they move into a partial that takes a `table` local and does
      # nothing but declare them:
      #
      #   <%# tasks/_columns.html.erb %>
      #   <% table.column "Kind", width: "30%" do |task| %>
      #     <%= link_to task.kind, task %>
      #   <% end %>
      #
      # The page renders the table with them:
      #
      #   <%= table_for @tasks, columns: "tasks/columns", rows_id: "task_rows" %>
      #
      # and a broadcast renders one row with the same file, so the two can never
      # drift:
      #
      #   <%# tasks/_row.html.erb %>
      #   <%= row_for task, columns: "tasks/columns" %>
      #
      #   broadcast_action_to "tasks", action: :upsert, target: "task_rows",
      #     partial: "tasks/row", locals: { task: self }
      #
      # Pass the same row_class: the table uses so a broadcast row matches. The
      # companion details row is not included — a stream action carries one element.
      def row_for(record, columns:, **options)
        builder = Components::Table.new(self, [ record ], **options)
        render(columns, table: builder)
        builder.row(record)
      end

      # Renders the same table chrome from plain data, so a static table gets the
      # same look without table_for's record/sort/pagination machinery.
      #
      #   <%= table_tag [ "Name", "Score" ], [ [ "Ann", 42 ], [ "Bob", 7 ] ], aligns: [ nil, :right ] %>
      #
      # headers and each row are arrays of cells. A cell is a value (rendered
      # as-is — pass a safe string for markup) or a { content:, **attrs } hash to
      # set attributes on its th/td. A row may itself be a { cells:, **attrs }
      # hash to set attributes on its <tr>. aligns and widths are per-column, and
      # rows_id puts an id on the <tbody>. Pass headers: nil (or []) to omit the
      # thead.
      def table_tag(headers, rows, **options)
        Components::TableTag.new(self, headers, rows, **options).render
      end

      # Declarative <dl> detail lists in the spirit of table_for.
      #
      #   <%= detail_list do |list| %>
      #     <% list.item "Created", candidate.created_at.to_fs(:short) %>
      #     <% list.item "Salary", candidate.salary_expectation %>
      #   <% end %>
      #
      #   <%= detail_list variant: :stacked do |list| %>
      #     <% list.item "Client ID", @application.uid, class: "font-mono" %>
      #     <% list.item "Redirect URIs", span: :full do %>
      #       ...
      #     <% end %>
      #   <% end %>
      #
      # variant: :inline (default) lays labels beside values in a two-column grid;
      # :stacked puts small uppercase labels above values, two columns on wide
      # screens. class: adds to the <dl>.
      #
      # A blank value — or a block that captures nothing — renders as an em dash.
      # Pass a block for markup-heavy values. An item's class: adds to its <dd>;
      # span: :full stretches a stacked item across both columns.
      def detail_list(variant: :inline, **options, &block)
        builder = Components::DetailList.new(self, variant: variant, **options)
        capture(builder, &block)
        builder.render
      end

      # The class string for a button, so the look composes with link_to, button_to
      # and form.submit alike.
      #
      #   <%= link_to "New label", new_label_path, class: button_classes(:primary) %>
      #
      # variant: :default, :primary, :ghost, :danger or :icon. size: :small or :large.
      def button_classes(variant = :default, size: nil)
        Components::Button.classes(variant, size: size)
      end

      # The class string for a form control outside a form builder, so a select_tag
      # or a hand-written input matches the controls the builder styles.
      #
      #   <%= select_tag "status", options_for_select(%w[Open Closed]), class: control_classes(:select) %>
      #   <%= search_field_tag "q", params[:q], class: control_classes(:input, size: :small) %>
      #
      # kind: :input, :text_area, :password, :date, :select, :check or :radio.
      # size: :small or :large sits a box level with a button_classes button of the
      # same size; a check or radio takes none. The classes come from
      # config.control_class, so they follow the app's own when it has some, and
      # size: only adds the gem's modifier while the gem's class is in use. Rails'
      # own *_tag helpers are never restyled; this is how to opt one in.
      def control_classes(kind, size: nil)
        Components::Control.classes(self, kind, size: size)
      end

      # Mounts the shared modal: a <dialog> around the turbo frame modal links load
      # into. Render it once, in the layout.
      #
      #   <%= modal_frame %>
      #
      # The dialog opens the moment the frame starts fetching, showing a skeleton
      # until the response lands, and swaps in an error panel with a retry if the
      # load fails. It closes on Escape, a backdrop click, or the panel's close
      # button, and clears the frame as it does. Needs Turbo and the <unmagic-modal>
      # element (import "unmagic/components/modal").
      def modal_frame(id: Components.configuration.modal_frame_id)
        Components::Modal.new(self, id: id).render
      end

      # link_to, aimed at the shared modal. Takes link_to's arguments.
      #
      #   <%= modal_link_to "Edit", edit_label_path(label), class: button_classes %>
      def modal_link_to(name = nil, options = nil, html_options = nil, &block)
        if block
          link_to(name, modal_link_options(options), &block)
        else
          link_to(name, options, modal_link_options(html_options))
        end
      end

      # A dialog's panel: a titled header with a close button, the body, and an
      # optional footer. This is what a modal link's response renders.
      #
      #   <%= dialog title: "Edit label", form: { model: @label } do |dialog, form| %>
      #     <%= form.field :name, "Name" %>
      #     <% dialog.footer { form.submit } %>
      #   <% end %>
      #
      # form: takes form_with's options and builds the form around the whole panel,
      # so a submit in the footer is inside it. Build the form here rather than
      # around the dialog: on a request aimed at the modal frame the dialog wraps
      # itself in that frame, and Turbo keeps only what is inside the frame. That is
      # also why the action can render the same template whether it is opened in the
      # modal or visited directly. Render it with status: :unprocessable_content on a
      # failed save and the dialog stays open showing the errors.
      #
      # Without form: the block is yielded just the panel builder. size: :wide for a
      # larger panel; close: false drops the close button; any other option rides on
      # the panel.
      def dialog(title: nil, form: nil, **options, &block)
        builder = Components::Dialog.new(self, title: title, **options)
        panel =
          if form
            form_with(**form) { |form_builder| builder.render(capture(builder, form_builder, &block)) }
          else
            builder.render(capture(builder, &block))
          end

        frame_id = Components.configuration.modal_frame_id
        if respond_to?(:turbo_frame_request_id) && turbo_frame_request_id == frame_id
          turbo_frame_tag(frame_id) { panel }
        else
          panel
        end
      end

      # A dialog already on the page, opened without a request.
      #
      #   <%= dialog_button "What's this?", dialog: "scopes_help", class: button_classes(:ghost) %>
      #
      #   <%= dialog_tag "scopes_help", title: "Scopes" do %>
      #     <p>Scopes limit what a token can do.</p>
      #   <% end %>
      #
      # The block is yielded the panel builder, for a footer. Extra options ride on
      # the <dialog>. Needs import "unmagic/components/dialog".
      def dialog_tag(id, title: nil, size: :default, close: true, **options, &block)
        builder = Components::Dialog.new(self, title: title, size: size, close: close)
        panel = builder.render(capture(builder, &block))

        options[:class] = class_names("UnmagicDialogBox", options[:class])
        options[:"aria-labelledby"] ||= builder.title_id if builder.titled?
        options[:data] = (options[:data] || {}).merge(unmagic_dialog: "")

        tag.dialog(panel, id: id, **options)
      end

      # A button that opens the dialog_tag with the given id.
      def dialog_button(content = nil, dialog:, **options, &block)
        options[:data] = (options[:data] || {}).merge(unmagic_dialog_open: dialog)

        tag.button(
          block ? capture(&block) : content,
          type: "button", "aria-haspopup": "dialog", "aria-controls": dialog, **options
        )
      end

      # A small pill of text: a status, a count, a label.
      #
      #   <%= badge "Draft" %>
      #   <%= badge "Overdue", tone: :bad %>
      #
      # tone: :neutral (default), :good, :warn, :bad, :info or :accent. Other
      # options go on the <span>.
      def badge(content = nil, tone: :neutral, **options, &block)
        options[:class] = class_names(Components::Badge.classes(tone), options[:class])
        tag.span(block ? capture(&block) : content, **options)
      end

      # A bordered surface for a section of a page.
      #
      #   <%= card title: "Members" do |card| %>
      #     <% card.actions { link_to "Invite", new_invitation_path, class: button_classes(:small) } %>
      #     <%= table_for @members do |table| %>...<% end %>
      #     <% card.footer { "3 of 5 seats used" } %>
      #   <% end %>
      #
      # flush: true drops the body's padding, for a table or list that runs edge to
      # edge. href: makes the whole card one link, for a row that opens a record;
      # nothing inside it should then be a link or button of its own. Other options
      # go on the card.
      def card(title: nil, href: nil, flush: false, **options, &block)
        builder = Components::Card.new(self, title: title, href: href, flush: flush, **options)
        builder.render(block ? capture(builder, &block) : nil)
      end

      # Blocks out an interface while it loads. The block is yielded a builder whose
      # shapes you arrange with your own markup, the way form_for yields f:
      #
      #   <%= skeleton label: "Loading candidate" do |s| %>
      #     <div class="flex items-center gap-3">
      #       <%= s.circle size: "3rem" %>
      #       <div class="flex-1"><%= s.text width: "60%" %><%= s.text width: "40%" %></div>
      #     </div>
      #     <%= s.text lines: 2 %>
      #   <% end %>
      #
      # s.text is a line sized by the font around it (lines: for a paragraph);
      # s.circle an avatar (size:); s.block an image or chart (height:, width:);
      # s.button a button_classes button (size: :small / :large). Each takes class:
      # and style: too. The shapes are hidden from screen readers, which hear label:
      # ("Loading…") once instead. Other options go on the wrapper.
      #
      # The same shapes stand alone as skeleton_text, skeleton_circle, skeleton_block
      # and skeleton_button. detail_list, page_header and card take skeleton: true
      # to render a skeleton version of themselves.
      def skeleton(label: nil, **options, &block)
        builder = Components::Skeleton.new(self)
        Components::Skeleton.group(self, label: label, **options) { capture(builder, &block) }
      end

      # A line of text (or lines: of them) outside a skeleton block.
      def skeleton_text(width: nil, lines: 1, **options)
        Components::Skeleton.new(self).text(width: width, lines: lines, **options)
      end

      # An avatar-sized circle outside a skeleton block.
      def skeleton_circle(size: "2.5rem", **options)
        Components::Skeleton.new(self).circle(size: size, **options)
      end

      # A rectangle outside a skeleton block.
      def skeleton_block(height: "8rem", width: nil, **options)
        Components::Skeleton.new(self).block(height: height, width: width, **options)
      end

      # A button-sized shape outside a skeleton block.
      def skeleton_button(size: nil, width: nil, **options)
        Components::Skeleton.new(self).button(size: size, width: width, **options)
      end

      # The top of a page. The block's output becomes the actions on the right.
      #
      #   <%= page_header title: @label.name, description: "Applied to 12 issues.",
      #         back: { text: "Labels", path: labels_path } do |header| %>
      #     <% header.badge "Archived", tone: :warn if @label.archived? %>
      #     <%= modal_link_to "Edit", edit_label_path(@label), class: button_classes %>
      #   <% end %>
      #
      # The builder also takes title and description blocks for markup, leading for
      # something before the title, such as an avatar, and trailing for markup
      # beside the title that is already rendered — a status partial, a row of
      # badges a helper returns — which can't go through badge because that would
      # wrap a badge in a badge. Other options go on the <header>.
      def page_header(title: nil, description: nil, back: nil, **options, &block)
        builder = Components::PageHeader.new(self, title: title, description: description, back: back, **options)
        builder.render(block ? capture(builder, &block) : nil)
      end

      # A tinted note stating the state of something in place: a health check, a
      # warning above a form.
      #
      #   <%= callout "DNS isn't verified", tone: :warn, badge: "Pending" do %>
      #     Add the TXT record below, then check again.
      #   <% end %>
      #
      # tone: :neutral (default), :good, :warn, :bad or :info, each with its own
      # icon (neutral has none); icon: false drops it. Other options go on the
      # callout.
      def callout(title = nil, tone: :neutral, badge: nil, icon: true, **options, &block)
        Components::Callout.new(self, title: title, tone: tone, badge: badge, icon: icon, **options)
          .render(block ? capture(&block) : nil)
      end

      # The dashed blank slate a list or table shows when there is nothing in it.
      # Renders through the same empty_state seam as a table's, so an app that
      # replaces one gets both.
      #
      #   <%= empty_state "No invitations yet." %>
      def empty_state(content = nil, **options, &block)
        Components.configuration.empty_state.call(self, block ? capture(&block) : content, **options)
      end

      # A timestamp shown in the viewer's own locale and time zone.
      #
      #   <%= local_time_tag comment.created_at, format: :relative %>   "3 hours ago"
      #   <%= local_time_tag invoice.due_at, format: :date %>           "16 Sept 2026"
      #   <%= local_time_tag event.starts_at %>                         "16 Sept 2026, 4:33 pm"
      #
      # format: :short, :medium (default), :long or :full for a date and time;
      # :date or :time for one of them; :relative for a distance that keeps itself
      # current ("just now", "5 minutes ago", "yesterday"), with the full time in its
      # title. compact: true shortens a relative time to "5m" / "3h". Past a week a
      # relative time settles into a date.
      #
      # The browser does the formatting with Intl, so there is nothing to
      # translate. Until the element upgrades, the server's own rendering in
      # Time.zone shows instead. A blank time renders an em dash. Needs import
      # "unmagic/components/time".
      def local_time_tag(time, format: :medium, compact: false, **options)
        return "—" if time.blank?

        Components::LocalTime.new(self, time, format: format, compact: compact, **options).render
      end

      # Explains something on hover or focus.
      #
      #   <%= tooltip "canonical", text: "The URL search engines treat as the original." %>
      #
      #   <%= tooltip text: "Copy the key" do %>
      #     <%= copy_button @key.secret %>
      #   <% end %>
      #
      # Plain text content is styled as a term — a dashed underline and a help
      # cursor — and made focusable; block content (a button, an icon) is left as it
      # is. term: overrides that guess. placement: :top (default) or :bottom, and it
      # flips when there's no room. The hint renders in the browser's top layer, so
      # nothing clips it. Needs import "unmagic/components/tooltip".
      def tooltip(content = nil, text:, placement: :top, term: nil, **options, &block)
        term = block.nil? if term.nil?
        Components::Tooltip.new(self, text: text, placement: placement, term: term, **options)
          .render(block ? capture(&block) : content)
      end

      # A dropdown of actions.
      #
      #   <%= menu do |menu| %>
      #     <% menu.link "Edit", edit_job_path(@job) %>
      #     <% menu.divider %>
      #     <% menu.button "Delete", job_path(@job), method: :delete, tone: :danger,
      #          form: { data: { turbo_confirm: "Delete this job?" } } %>
      #   <% end %>
      #
      # With no label the trigger is a ⋮ icon button labelled "More actions"; pass
      # one for a text button with a chevron. align: :end (default) lines the panel
      # up with the trigger's right edge, :start with its left. link and button take
      # link_to's and button_to's arguments, plus tone: :danger.
      #
      # It closes on an outside click, Escape, choosing an item, or a Turbo
      # navigation. Arrow keys, Home and End move between items, and opening it from
      # the keyboard focuses the first. Other options go on the element. Needs import
      # "unmagic/components/menu".
      def menu(label = nil, align: :end, **options, &block)
        builder = Components::Menu.new(self, label: label, align: align, **options)
        capture(builder, &block)
        builder.render
      end

      # A row of tabs.
      #
      #   <%= tabs id: "response" do |tabs| %>
      #     <% tabs.tab "Body" %>
      #     <% tabs.tab "Headers" %>
      #     <% tabs.tab "Preview", disabled: "HTML only" %>
      #     <% tabs.panel do %>...<% end %>
      #     <% tabs.panel do %>...<% end %>
      #   <% end %>
      #
      # Panels pair with the enabled tabs in order; a tab with disabled: shows its
      # reason and takes no panel. active: true picks the first tab shown. Arrow
      # keys, Home and End move between tabs. With an id:, the chosen tab is
      # remembered for the tab's session and survives a morph refresh.
      #
      # Tabs with href: are links to separate pages instead, rendered on the server
      # with no script; mark the current one active: true.
      #
      #   <%= tabs do |tabs| %>
      #     <% tabs.tab "All", href: invitations_path, active: @status.nil? %>
      #     <% tabs.tab "Replied", href: invitations_path(status: "replied"), active: @status == "replied" %>
      #   <% end %>
      #
      # Needs import "unmagic/components/tabs" for panels.
      def tabs(id: nil, **options, &block)
        builder = Components::Tabs.new(self, id: id, **options)
        capture(builder, &block)
        builder.render
      end

      # A button that copies text to the clipboard, showing a check for a moment
      # once it has.
      #
      #   <%= copy_button @key.secret %>
      #   <%= copy_button from: "install_command" do %>Copy command<% end %>
      #
      # from: copies the value of the input, or the text of the element, with that
      # id when clicked, so the text isn't duplicated into an attribute. Without a
      # block it's an icon button labelled label: ("Copy"). Other options go on the
      # <button>. It fires unmagic-clipboard:copy, or unmagic-clipboard:error when
      # the browser refuses. Needs import "unmagic/components/clipboard".
      def copy_button(text = nil, from: nil, label: nil, **options, &block)
        Components::CopyButton.new(self, text: text, from: from, label: label, **options)
          .render(block ? capture(&block) : nil)
      end

      # text_area_tag, growing with its content. See FormBuilder#autogrow_text_area.
      def autogrow_text_area_tag(name, content = nil, **options)
        Components::Autogrow.wrap(self, text_area_tag(name, content, Components::Control.merge(self, options, :text_area)))
      end

      # A hidden field holding a fresh UUIDv7, outside a form builder. See
      # FormBuilder#uuid_field.
      #
      #   <%= uuid_input_tag "message[id]" %>
      def uuid_input_tag(name, **options)
        Components::UuidInput.new(self, name, **options).render
      end

      # Turns the request's flashes into toasts. Render it once, in the layout.
      #
      #   <%= flash_toasts %>
      #
      # Set flash[:notice] or flash[:alert] as usual and it pops up, dismisses
      # itself after duration: milliseconds, and survives a morph refresh while it
      # is on screen. Hovering or focusing a toast holds it open. The tone comes
      # from config.flash_tones (notice is :good, alert :bad).
      #
      # duration: 0 keeps a toast up until it is dismissed — for a test that asserts
      # on one without racing the timer, or a message that should not go by itself.
      #
      # Pass the flashes to show when some aren't meant for the user:
      #
      #   <%= flash_toasts flash.to_hash.except("copy_link") %>
      #
      # Pop one from a stream with turbo_stream.toast. Needs import
      # "unmagic/components/toasts".
      def flash_toasts(flashes = flash, duration: 5000)
        Components::Toasts.new(self, flashes, duration: duration).render
      end

      # Server-rendered words for the confirm dialog that replaces window.confirm for
      # data-turbo-confirm. Render it once in the layout when the defaults ("Are you
      # sure?", "Cancel", "Confirm") need translating; without it the dialog uses
      # them in English. Needs import "unmagic/components/confirm".
      def confirm_dialog_template
        Components::ConfirmTemplate.new(self).render
      end

      # A clock counting up from a moment the server named, a second at a time — the
      # difference between work that takes a minute and work that has hung.
      #
      #   <%= elapsed_tag tool_call.started_at %>                        "3m 5s"
      #   <%= elapsed_tag session.expires_at, direction: :down %>        "42s"
      #
      # direction: :up (default) counts from the time, :down counts to it and stops
      # at zero, firing unmagic-elapsed:end. The server renders the current reading,
      # so it is right before the script loads. The same words as a settled
      # duration: 640ms, 2s, 3m 5s, 1h 4m 2s (the unmagic.components.elapsed.* keys).
      # A blank time renders an em dash. Other options go on the element. Needs
      # import "unmagic/components/elapsed".
      def elapsed_tag(time, direction: :up, **options)
        return "—" if time.blank?

        Components::Elapsed.new(self, time, direction: direction, **options).render
      end

      # Server-rendered HTML revealed at a steady pace as fuller renders of it are
      # streamed in — a model's reply, reading as one smooth stream rather than the
      # bursts it arrives in.
      #
      #   <%= streaming_markdown_tag id: "message_1_content", streaming: true do %>
      #     <%= Markdown.render(message.content) %>
      #   <% end %>
      #
      # Send each flush with turbo_stream.stream_markdown, carrying the whole reply
      # so far. The gem never parses Markdown: the content is the host's own
      # rendered, sanitised HTML. final: true settles it, refusing any later flush
      # (a stopped or failed reply). streaming: true marks it aria-busy until it
      # catches up, so a live region announces it once. Reduced motion paints each
      # flush in full. Other options go on the element. Needs import
      # "unmagic/components/streaming_markdown".
      def streaming_markdown_tag(content = nil, id:, final: false, streaming: false, **options, &block)
        Components::StreamingMarkdown.new(self, id: id, final: final, streaming: streaming, **options)
          .render(block ? capture(&block) : content)
      end

      # A person's or organisation's picture, falling back to their initials on one
      # of six tints picked from the name, the same on every page and server.
      #
      #   <%= avatar "Ada Lovelace" %>
      #   <%= avatar @user.name, src: @user.avatar_url, size: :large %>
      #   <%= avatar "Acme Ltd", shape: :square %>
      #
      # size: :small, :medium (default) or :large. shape: :circle (default) or
      # :square. tint: false for the neutral surface. skeleton: true renders a
      # skeleton circle of the same size. A blank src falls back to the initials,
      # and a broken image shows them through it. The avatar is role="img" named
      # for the person; pass "aria-hidden": true when the name is already written
      # beside it. Other options go on the <span>.
      def avatar(name, src: nil, size: :medium, shape: :circle, tint: true, skeleton: false, **options)
        Components::Avatar.new(self, name, src: src, size: size, shape: shape, tint: tint, skeleton: skeleton, **options).render
      end

      # A stack of avatars.
      #
      #   <%= avatar_group max: 3, size: :small do |group| %>
      #     <% @members.each { |member| group.avatar member.name, src: member.avatar_url } %>
      #   <% end %>
      #
      # Past max: the rest collapse into a "+N" whose title lists them. The group
      # sets size: and shape: for every avatar in it. Other options go on the <div>.
      def avatar_group(max: nil, size: :medium, shape: :circle, **options, &block)
        builder = Components::AvatarGroup.new(self, max: max, size: size, shape: shape, **options)
        capture(builder, &block)
        builder.render
      end

      # A list whose items can be dragged, or moved with the keyboard, into a new
      # place — here, or in another list sharing its namespace.
      #
      #   <%= sortable_list namespace: "cards", params: { column_id: column.id } do |list| %>
      #     <% column.cards.ordered.each do |card| %>
      #       <%= list.item(card) { render card } %>
      #     <% end %>
      #   <% end %>
      #
      # list.item takes a record, whose key and rank come from
      # config.sortable_item (unmagic-sortable sets it to signed keys), or key: and
      # rank: directly; label: is what a screen reader calls it. Put a
      # sortable_handle in an item to drag it only by that, which keeps the rest of
      # it clickable; without one the whole item drags once the pointer moves, and
      # the item is its own keyboard stop.
      #
      # namespace: lets items move between lists that share it. params: are posted
      # with a drop into this list (the destination column). orientation:
      # :vertical (default), :horizontal or :grid decides which arrow keys move an
      # item. label: names the list in announcements.
      #
      # A drop fires a cancelable unmagic-sortable:move, then PATCHes url:
      # (config.sortable_url by default) with moved, original, prev, next and the
      # params. Keyboard: Space or Enter picks an item up, the arrows move it (the
      # other arrows move it between lists), Space drops it, Escape puts it back.
      # Escape cancels a pointer drag too. Other options go on the element. Needs
      # import "unmagic/components/sortable".
      def sortable_list(namespace: nil, params: {}, url: nil, orientation: :vertical, label: nil, **options, &block)
        builder = Components::Sortable::List.new(self, namespace: namespace, params: params, url: url,
          orientation: orientation, label: label, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The grip a sortable item is dragged by, and its keyboard stop.
      #
      #   <%= sortable_handle %>
      #   <%= sortable_handle label: "Move #{step.name}" %>
      #
      # label: defaults to "Drag to reorder". Other options go on the <button>.
      def sortable_handle(label: nil, **options)
        Components::Sortable.handle(self, label: label, **options)
      end

      # A Trello-style board of reorderable columns of reorderable cards.
      #
      #   <%= board id: "roadmap" do |board| %>
      #     <% @columns.each do |column| %>
      #       <% board.column column, title: column.name, params: { column_id: column.id } do |col| %>
      #         <% col.actions { menu { |m| m.link "Rename", edit_column_path(column) } } %>
      #         <% column.cards.ordered.each do |card| %>
      #           <% col.card(card) { render card } %>
      #         <% end %>
      #         <% col.add url: cards_path, field: "card[title]", params: { "card[column_id]" => column.id } %>
      #       <% end %>
      #     <% end %>
      #     <% board.add_column url: columns_path, field: "column[name]" %>
      #   <% end %>
      #
      # id: names the board and its lists: cards move between any of its columns,
      # posting the column's params:, and columns move along the board. url: is where
      # drops post (config.sortable_url by default); columns_url: overrides it for
      # columns. sortable_columns: false fixes the columns in place. column_height:
      # is how tall a column grows before its cards scroll (75dvh), through the
      # --unmagic-board-column-height knob.
      #
      # A column's header is its drag handle, with a grip for the keyboard; its
      # actions stay clickable. board.column takes a record or key:/rank:, and
      # count: when it shows fewer cards than it has. col.card takes what
      # sortable_list's item does. col.add and board.add_column open into a
      # one-field form that submits on Enter, closes on Escape, and stays open to add
      # another. Other options go on the root <div>. Needs import
      # "unmagic/components/sortable" and "unmagic/components/board".
      def board(id:, url: nil, columns_url: nil, sortable_columns: true, label: nil, column_height: nil, **options, &block)
        builder = Components::Board.new(self, id: id, url: url, columns_url: columns_url,
          sortable_columns: sortable_columns, label: label, column_height: column_height, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The scrolling region an AI chat's turns are rendered into — the root of the
      # ai_chat_* components.
      #
      #   <%= ai_chat id: "entries" do |chat| %>
      #     <% chat.welcome do %><%= ai_chat_welcome heading: "What can I help with?" %><% end %>
      #     <%= render @chat.timeline %>
      #   <% end %>
      #
      # It renders no entries of its own: render yours with a partial per entry
      # type. id: is required, since it is what turns are upserted into. The log is
      # role="log", announced politely. It follows new content while the reader is
      # at the bottom and stops when they scroll up (follow: false to never follow),
      # showing a jump-to-latest button meanwhile (scroll_to_latest: false for none).
      # scroller: is a selector for the scrolling box when it isn't the page.
      # chat.welcome shows while the conversation is empty and hides as the first
      # entry arrives. Other options go on the log. Needs import
      # "unmagic/components/autoscroll" and Turbo.
      def ai_chat(id:, scroller: nil, follow: true, scroll_to_latest: true, **options, &block)
        builder = Components::AIChat::Transcript.new(self, id: id, scroller: scroller, follow: follow,
          scroll_to_latest: scroll_to_latest, **options)
        entries = block ? capture(builder, &block) : nil
        builder.render(entries)
      end

      # One turn: a user's bubble of plain text, or an assistant's unbubbled prose.
      #
      #   <%= ai_chat_message role: :user, id: dom_id(message) do %><%= message.content %><% end %>
      #
      #   <%= ai_chat_message role: :assistant, id: dom_id(message), streaming: message.pending? do |turn| %>
      #     <% turn.reasoning(duration: message.thinking_seconds) { Markdown.render(message.thinking) } %>
      #     <% turn.actions do %><%= ai_chat_action_bar for: dom_id(message) do |bar| %>…<% end %><% end %>
      #     <%= Markdown.render(message.content) %>
      #   <% end %>
      #
      # role: :user or :assistant. An assistant body is the host's rendered,
      # sanitised HTML, inside an <unmagic-streaming-markdown> whose id is
      # "#{id}_content" — the target for turbo_stream.stream_markdown. streaming:
      # true shows a thinking spinner until the first token and marks the body
      # busy; final: true refuses any later flush (a stopped or failed reply). A
      # settled assistant turn with nothing in it renders hidden, keeping its id.
      #
      # Parts: reasoning (ai_chat_reasoning's options), actions, branches, and
      # attachments (above a user's bubble). optimistic: { id:, text: } names the
      # form fields a composer's template fills, and dims the bubble until the
      # server's own turn replaces it. Other options go on the root <div>.
      def ai_chat_message(content = nil, role:, id: nil, streaming: false, final: false, optimistic: nil, **options, &block)
        builder = Components::AIChat::Message.new(self, role: role, id: id, streaming: streaming, final: final,
          optimistic: optimistic, **options)
        body = block ? capture(builder, &block) : content
        builder.render(body)
      end

      # The model's thinking, collapsed above its reply.
      #
      #   <%= ai_chat_reasoning duration: 12.4 do %><%= Markdown.render(thinking) %><% end %>
      #
      # Shut by default (open: true to open it). streaming: true shows "Thinking…"
      # with a spinner; duration: (seconds) titles it "Thought for 12s"; title:
      # replaces "Thought process". reasoning.block records one more block. Blank
      # content renders nothing. Other options go on the <details>.
      def ai_chat_reasoning(content = nil, title: nil, streaming: false, duration: nil, open: false, **options, &block)
        builder = Components::AIChat::Reasoning.new(self, title: title, streaming: streaming, duration: duration,
          open: open, **options)
        body = block ? capture(builder, &block) : content
        builder.render(body)
      end

      # One tool the agent reached for, as a row in a timeline.
      #
      #   <%= ai_chat_tool_call name: call.name, state: call.state, id: dom_id(call) do |tool| %>
      #     <% tool.summary call.summary %>
      #     <% tool.timing started_at: call.started_at, duration: call.duration %>
      #     <% tool.asked call.arguments %>
      #     <% tool.answered call.response %>
      #   <% end %>
      #
      # state: :queued, :running, :waiting, :done or :failed. A done call shows
      # icon: (what the call was about) in place of a tick. Consecutive rows are
      # joined by a line; timeline: false leaves a row out of the run. Mark the
      # hidden entries between two rows (a tool result's anchor) with
      # data-ai-chat-timeline="gap" so the line runs over them.
      #
      # Parts: summary, timing (a live clock while running), asked and answered
      # (ai_chat_payload), failures (a count for a call that mostly worked),
      # progress (a line beside the spinner, with id "#{id}_progress" to replace),
      # and made (content kept outside the fold). With no payloads there is no
      # disclosure. open: true opens it. Other options go on the root <div>.
      def ai_chat_tool_call(name:, state:, id: nil, icon: nil, open: false, timeline: true, **options, &block)
        builder = Components::AIChat::ToolCall.new(self, name: name, state: state, id: id, icon: icon, open: open,
          timeline: timeline, **options)
        capture(builder, &block) if block
        builder.render
      end

      # A tool's payload, or anything else to read exactly as written.
      #
      #   <%= ai_chat_payload call.response, label: "Answered", duration: call.duration %>
      #
      # A Hash, an Array, or a string holding JSON is laid out a key to a line as
      # :json; anything else is :plaintext. language: overrides that. The code block
      # renders through config.code_block, so a host's highlighter colours it. It
      # scrolls past a height and wraps long lines, and is reachable by keyboard.
      # copy: true adds a copy button. A nil payload renders nothing. Other options
      # go on the root <div>.
      def ai_chat_payload(payload, label: nil, language: nil, duration: nil, copy: false, **options)
        Components::AIChat::Payload.new(self, payload, label: label, language: language, duration: duration,
          copy: copy, **options).render
      end

      # A turn that fell over.
      #
      #   <%= ai_chat_failure "The assistant couldn't finish this reply." do |failure| %>
      #     <% failure.cause "Faraday::TimeoutError: execution expired" %>
      #     <% failure.detail "Where it happened", error.backtrace.join("\n"), language: :plaintext %>
      #     <% failure.retry { button_to "Try again", retry_path(chat) } %>
      #   <% end %>
      #
      # The sentence is for whoever asked; the details, folded away, are for
      # whoever works on the assistant. Render it below a turn's body, never in
      # place of it. live: true adds role="alert", for one streamed in. Other
      # options go on the root <div>.
      def ai_chat_failure(message = nil, live: false, **options, &block)
        builder = Components::AIChat::Failure.new(self, live: live, **options)
        content = block ? capture(builder, &block) : nil
        builder.render(message || content)
      end

      # The checklist an agent is working through.
      #
      #   <%= ai_chat_plan id: "plan" do |plan| %>
      #     <% @plan.steps.each { |step| plan.step step.title, state: step.status } %>
      #   <% end %>
      #
      # A step's state: is :pending, :in_progress, :waiting or :completed; a block
      # adds detail under it. The count reads completed/total, from the steps
      # unless completed:/total: are given. With no steps it shows empty: rather
      # than nothing, since it is a broadcast target. open: false starts it shut;
      # collapsible: false renders a plain section. title_tag: sets the heading
      # level (:h2). Other options go on the root.
      def ai_chat_plan(title: nil, completed: nil, total: nil, open: true, empty: nil, collapsible: true,
        title_tag: :h2, **options, &block)
        builder = Components::AIChat::Plan.new(self, title: title, completed: completed, total: total, open: open,
          empty: empty, collapsible: collapsible, title_tag: title_tag, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The files an agent has put aside while it works.
      #
      #   <%= ai_chat_workspace id: "workspace" do |workspace| %>
      #     <% @files.each { |file| workspace.file file.path, size: file.byte_size } %>
      #   <% end %>
      #
      # A flat list of paths; url: makes a row a link and icon: changes its glyph
      # (:file). Takes ai_chat_plan's title:, count:, open:, empty:, collapsible:
      # and title_tag:. Other options go on the root.
      def ai_chat_workspace(title: nil, count: nil, open: true, empty: nil, collapsible: true, title_tag: :h2,
        **options, &block)
        builder = Components::AIChat::Workspace.new(self, title: title, count: count, open: open, empty: empty,
          collapsible: collapsible, title_tag: title_tag, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The box a person types into, with Send — or Stop while a turn runs.
      #
      #   <%= form_with model: Message.new, url: chat_messages_path(@chat), id: "composer" do |form| %>
      #     <%= ai_chat_composer form: form, field: :content, state: @chat.run_state do |composer| %>
      #       <% composer.optimistic id: "message[client_id]", container: "#entries" %>
      #     <% end %>
      #   <% end %>
      #   <%= ai_chat_stop_form chat_stop_path(@chat) %>
      #
      # The form needs an id:. state: :idle, :running, :stopping or :waiting
      # changes only the button, never the field, so a draft survives it; the
      # button's region has id "#{form_id}_action", to redraw with
      # ai_chat_composer_action. Enter sends and Shift+Enter makes a new line, and
      # Enter does nothing while there is no Send. The form resets after a
      # successful submit. label: renames Send; placeholder: and rows: go to the
      # field; stop_form: is the id Stop submits ("stop_turn").
      #
      # Parts: optimistic (draws the question into the transcript as it's sent,
      # under an id <unmagic-uuid-input> mints), attach and actions (controls in
      # the box), and menu (an ai_chat_slash_menu). Other options go on the root
      # <div>. Needs import "unmagic/components/ai_chat" and Turbo.
      def ai_chat_composer(form:, field:, state: :idle, label: nil, stop_form: Components::AIChat::Composer::STOP_FORM,
        placeholder: nil, rows: 2, **options, &block)
        builder = Components::AIChat::Composer.new(self, form: form, field: field, state: state, label: label,
          stop_form: stop_form, placeholder: placeholder, rows: rows, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The composer's button region on its own, for a broadcast that redraws it
      # as the turn's state changes.
      #
      #   <%= ai_chat_composer_action form: "composer", state: :running %>
      def ai_chat_composer_action(form:, state:, label: nil, stop_form: Components::AIChat::Composer::STOP_FORM)
        Components::AIChat::Composer.action(self, form: form, state: state, label: label, stop_form: stop_form)
      end

      # The empty form Stop submits. Render it outside the composer's form — a form
      # can't sit inside another — and Stop reaches it by id.
      #
      #   <%= ai_chat_stop_form chat_stop_path(@chat) %>
      def ai_chat_stop_form(url, id: Components::AIChat::Composer::STOP_FORM, method: :post)
        form_with(url: url, method: method, id: id, class: "UnmagicAIChatStopForm") { "" }
      end

      # The agent asking something it can't work out on its own.
      #
      #   <%= ai_chat_request state: :waiting, url: answer_path(@chat), live: true do |request| %>
      #     <% request.question "Which chats should it read?", header: "Scope" do |q| %>
      #       <% q.option "This chat", description: "Only the one it asked about" %>
      #       <% q.option "Any chat", description: "Every conversation, from now on" %>
      #     <% end %>
      #     <% request.aside "Or say something else in the box below." %>
      #   <% end %>
      #
      # Ask with questions (multiple: true for checkboxes), or with request.form
      # { |form| … } for fields of your own — not both. state: :waiting renders
      # the form, posting answers[i][] (url:, method: :patch, scope: :response for
      # a form); :accepted, :declined, :cancelled or :timed_out keeps the
      # questions and shows what was picked (question picked:) or answered
      # (request.answer). request.decline adds a Decline that skips validation.
      # prompt: is the sentence above; label: renames Answer. live: true adds
      # role="alert" for one streamed in, and takes focus if nothing has it. Other
      # options go on the root <div>.
      def ai_chat_request(state:, url: nil, method: :patch, prompt: nil, label: nil, scope: :response, live: false,
        **options, &block)
        builder = Components::AIChat::Request.new(self, state: state, url: url, method: method, prompt: prompt,
          label: label, scope: scope, live: live, **options)
        capture(builder, &block) if block
        builder.render
      end

      # An agent asking to be allowed something, with its reasoning.
      #
      #   <%= ai_chat_permission tool: "delete_resource", state: :waiting, url: permission_path(@call) do |ask| %>
      #     <% ask.argument "chat_id", 42 %>
      #     <% ask.summary { markdown(@call.summary) } %>
      #     <% ask.allow confirm: "Let this chat delete files? This can't be undone." %>
      #     <% ask.allow "Allow for any chat", params: { widened: true } %>
      #     <% ask.refuse %>
      #   <% end %>
      #
      # state: :waiting, :granted, :refused or :lapsed (answered in the chat, with
      # nothing granted). The tool name is shown as given. The first allow is the
      # prominent one; offer a second, wider allow only when there is something to
      # widen. allow posts and refuse deletes to url:, each with its own params:
      # and confirm:. Focus goes to the card, never to Allow. outcome: replaces an
      # answered card's sentence; live: true adds role="alert". Other options go on
      # the root <div>.
      def ai_chat_permission(tool:, state:, url: nil, live: false, outcome: nil, **options, &block)
        builder = Components::AIChat::Permission.new(self, tool: tool, state: state, url: url, live: live,
          outcome: outcome, **options)
        capture(builder, &block) if block
        builder.render
      end

      # An offer the agent made in passing, which the reader can take up or not.
      #
      #   <%= ai_chat_proposal state: fact.decision, id: dom_id(fact) do |offer| %>
      #     <% offer.claim "Prefers to be called Ana" %>
      #     <% offer.meta "About Ana Silva · 80% sure" %>
      #     <% offer.accept { button_to "Save", approve_path(fact), class: button_classes(size: :small) } %>
      #     <% offer.reject { button_to "Dismiss", reject_path(fact), class: button_classes(size: :small) } %>
      #   <% end %>
      #
      # state: :pending (default), :accepted or :rejected. The actions show while
      # pending; a decided card shows outcome: ("Saved", "Dismissed") and a
      # rejected one dims. icon: is its glyph (:lightbulb). It is marked not-prose,
      # to sit inside a reply. Other options go on the <aside>.
      def ai_chat_proposal(state: :pending, icon: :lightbulb, id: nil, **options, &block)
        builder = Components::AIChat::Proposal.new(self, state: state, icon: icon, id: id, **options)
        capture(builder, &block) if block
        builder.render
      end

      # A quotation of a record, rendered from the record.
      #
      #   <%= ai_chat_citation do |cite| %>
      #     <% cite.avatar src: message.sender.avatar_url %>
      #     <% cite.who message.sender.name %>
      #     <% cite.when message.sent_at, url: message_path(message) %>
      #     <% cite.quote message.body %>
      #   <% end %>
      #
      # The quote is escaped plain text with its line breaks kept. cite.avatar with
      # no block draws the gem's avatar for who:. compact: true is one line, for a
      # list of sources. Nothing given renders nothing. Other options go on the
      # <figure>.
      def ai_chat_citation(compact: false, **options, &block)
        builder = Components::AIChat::Citation.new(self, compact: compact, **options)
        capture(builder, &block) if block
        builder.render
      end

      # What an empty conversation says, and suggestions that start one.
      #
      #   <%= ai_chat_welcome heading: "What can I help with?" do |welcome| %>
      #     <% welcome.suggestion "Who hasn't replied yet?" %>
      #     <% welcome.suggestion "Invite someone to…", fill: true %>
      #   <% end %>
      #
      # Pressing a suggestion puts its text (value:, or the label) in the composer
      # form with id composer: ("composer") and sends it, unless fill: true or a
      # turn is running. field: names the field when the form has several.
      # heading_tag: sets the heading level. Other options go on the root <div>.
      # Needs import "unmagic/components/ai_chat".
      def ai_chat_welcome(heading:, heading_tag: :h2, composer: "composer", field: nil, **options, &block)
        builder = Components::AIChat::Welcome.new(self, heading: heading, heading_tag: heading_tag,
          composer: composer, field: field, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The files a sent turn carries.
      #
      #   <%= ai_chat_attachments align: :end do |files| %>
      #     <% message.files.each { |blob| files.file blob.filename, size: blob.byte_size, url: url_for(blob) } %>
      #   <% end %>
      #
      # align: :end for a user's turn. thumbnail: is an image URL; without one the
      # tile shows a file glyph. None renders nothing. Other options go on the <ul>.
      def ai_chat_attachments(align: :start, **options, &block)
        builder = Components::AIChat::Attachments.new(self, align: align, **options)
        capture(builder, &block) if block
        builder.render
      end

      # A region that takes dropped and pasted files for a composer.
      #
      #   <%= ai_chat_dropzone input: "#composer_files", chips: "#composer [data-ai-chat-chips]" do %>
      #     …the page…
      #   <% end %>
      #
      # input: is the file input the files land in, which is also the way in for
      # anyone who can't drag. With url: each file is uploaded on the spot
      # (POST, as file) and the JSON response's value is posted with the message
      # under field:; without it the files wait on the input. chips: is where the
      # attached files are listed. label: is the overlay's words. It fires
      # unmagic-dropzone:attach and :error. Other options go on the element. Needs
      # import "unmagic/components/dropzone".
      def ai_chat_dropzone(input:, url: nil, field: nil, chips: nil, label: nil, **options, &block)
        Components::AIChat::Dropzone.new(self, input: input, url: url, field: field, chips: chips, label: label,
          **options).render(block ? capture(&block) : nil)
      end

      # Commands offered on a slash in a composer.
      #
      #   <% composer.menu do %>
      #     <%= ai_chat_slash_menu above: true do |menu| %>
      #       <% @skills.each { |skill| menu.item skill.name, description: skill.description } %>
      #     <% end %>
      #   <% end %>
      #
      # Every item is rendered and the typing filters them. Arrows move, Enter or
      # Tab takes one, Escape closes. Picking writes "/name " at the cursor.
      # arguments: lists hints after the name. for: is the field's id (the
      # composer's by default); trigger: is the character ("/"); above: opens it
      # upwards. No items renders nothing. Other options go on the element. Needs
      # import "unmagic/components/slash_menu".
      def ai_chat_slash_menu(for: nil, id: nil, trigger: "/", above: false, insert: nil, **options, &block)
        builder = Components::AIChat::SlashMenu.new(self, for: binding.local_variable_get(:for), id: id,
          trigger: trigger, above: above, insert: insert, **options)
        capture(builder, &block) if block
        builder.render
      end

      # The controls under a turn.
      #
      #   <%= ai_chat_action_bar for: dom_id(message) do |bar| %>
      #     <% bar.copy message.content %>
      #     <% bar.action "Try again", retry_message_path(message), icon: :rotate_cw, method: :post %>
      #   <% end %>
      #
      # A toolbar: one Tab stop, arrow keys between controls. for: is the turn's id.
      # reveal: :hover (default) shows it on hover or focus and always on touch;
      # :always shows it. action takes icon: and method: (:get is a link), plus
      # confirm:; control takes any markup. No controls renders nothing. Other
      # options go on the element. Needs import "unmagic/components/toolbar".
      def ai_chat_action_bar(for:, reveal: :hover, **options, &block)
        builder = Components::AIChat::ActionBar.new(self, for: binding.local_variable_get(:for), reveal: reveal, **options)
        capture(builder, &block) if block
        builder.render
      end

      # Walking between versions of a turn.
      #
      #   <%= ai_chat_branch_picker index: 2, count: 3, previous: branch_path(m, 1), next: branch_path(m, 3) %>
      #
      # A nil previous: or next: is a disabled end. count: 1 renders nothing.
      # method: other than :get makes the steps buttons. Other options go on the
      # <div>. Needs import "unmagic/components/ai_chat" to keep focus on the
      # picker as the turn is replaced.
      def ai_chat_branch_picker(index:, count:, previous: nil, next: nil, method: :get, **options)
        Components::AIChat::BranchPicker.new(self, index: index, count: count, previous: previous,
          next: binding.local_variable_get(:next), method: method, **options).render
      end

      private

      def modal_link_options(html_options)
        html_options = (html_options || {}).dup
        html_options[:data] = { turbo_frame: Components.configuration.modal_frame_id }.merge(html_options[:data] || {})
        html_options
      end

      def table_pagy_for(collection, paginate)
        case paginate
        when true then Components.configuration.pagy_for.call(self, collection)
        when false, nil then nil
        else paginate
        end
      end
    end
  end
end
