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
      # The builder also takes title and description blocks for markup, and leading
      # for something before the title, such as an avatar. Other options go on the
      # <header>.
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
        Components::Autogrow.wrap(self, text_area_tag(name, content, options))
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
