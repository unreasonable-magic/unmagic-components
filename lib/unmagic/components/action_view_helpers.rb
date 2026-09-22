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

      # A key or a combination of keys, drawn as key caps.
      #
      #   <%= kbd "Esc" %>
      #   <%= kbd :mod, "K" %>
      #   <%= kbd hotkey: "mod+shift+p" %>
      #   <%= kbd "G", "I", sequence: true %>
      #
      # Named keys (:cmd, :ctrl, :alt, :shift, :enter, :esc, :tab, :space, the
      # arrows, :backspace, :delete) draw a glyph and carry their spoken name for
      # a screen reader. :mod is ⌘ on Apple platforms and Ctrl elsewhere, guessed
      # from the request and corrected by the browser when hotkey.js is loaded.
      # hotkey: takes the same "mod+k" syntax. sequence: true is keys pressed one
      # after another. Other options go on the outer <kbd>.
      def kbd(*keys, hotkey: nil, sequence: false, **options)
        Components::Kbd.new(self, *keys, hotkey: hotkey, sequence: sequence, **options).render
      end

      # The trail of pages above this one.
      #
      #   <%= breadcrumbs do |crumbs| %>
      #     <% crumbs.link "Settings", settings_path %>
      #     <% crumbs.link "Integrations", settings_integrations_path %>
      #     <% crumbs.current "GitHub" %>
      #   <% end %>
      #
      # crumbs.link takes link_to's arguments; crumbs.current is the page you are
      # on, optional and last. An empty trail renders nothing. label: names the
      # <nav> ("Breadcrumb"); other options go on it. page_header takes the same
      # block as its breadcrumbs part.
      def breadcrumbs(label: nil, **options, &block)
        builder = Components::Breadcrumbs.new(self, label: label, **options)
        capture(builder, &block)
        builder.render
      end

      # A nested, collapsible list of things inside other things: a repository's
      # files, an organisation's teams, a documentation sidebar.
      #
      #   <%= tree_view label: "Files" do |tree| %>
      #     <% tree.branch "app", icon: :folder do |app| %>
      #       <% app.leaf "user.rb", href: blob_path("app/models/user.rb"), icon: :file, current: true %>
      #     <% end %>
      #     <% tree.leaf "Gemfile", href: blob_path("Gemfile"), icon: :file %>
      #   <% end %>
      #
      # label: names the root list and is required. guides: false drops the
      # vertical line beside each level (true). tree.branch(label, icon:, open:,
      # meta:) yields a builder with the same branch and leaf, to any depth; it is
      # open when a leaf inside it is current, unless open: says otherwise, and a
      # branch with nothing in it says "Empty". tree.leaf(label, href:, icon:,
      # current:, meta:) is a link with href: and plain text without; a block
      # gives it markup in place of label, and current: true marks it
      # aria-current="page". meta: is a short reading kept whole at the row's end
      # (a size, a count) while the label truncates. icon: is an Icons name
      # (none by default). Other options on a branch or leaf go on its row; a
      # string label is also the row's title. An empty tree renders nothing.
      # Other options go on the root <ul>. No script: Tab moves through the open
      # rows, and Enter or Space folds a branch.
      def tree_view(label:, guides: true, **options, &block)
        builder = Components::TreeView.new(self, label: label, guides: guides, **options)
        capture(builder, &block) if block
        builder.render
      end

      # Links to the pages around this one, for anything that pages like Pagy.
      #
      #   <%= pagination @pagy %>
      #   <%= pagination @pagy, window: 1, turbo_frame: "results" %>
      #
      # The pager answers previous, next and page_url(page or :previous/:next);
      # one that also answers page and last gets numbered links, window: pages
      # either side of this one, with the first and last always shown. On a
      # narrow screen the numbers give way to "3 of 12". turbo_frame: points the
      # links at a frame. One page renders nothing. This is what a table_for
      # draws under itself through config.pagination. Other options go on the <nav>.
      def pagination(pager, window: 2, turbo_frame: nil, label: nil, **options)
        Components::Pagination.new(self, pager, window: window, turbo_frame: turbo_frame, label: label, **options).render
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

      # A button, a link that looks like one, or a button_to form, from one call.
      #
      #   <%= button "Save", :primary, type: "submit" %>
      #   <%= button "New label", href: new_label_path, icon: :plus %>
      #   <%= button "Delete", :danger, href: label_path(@label), method: :delete, form: { data: { turbo_confirm: "Sure?" } } %>
      #   <%= button "Close", :icon, icon: :x %>
      #   <%= button "Saving", :primary, loading: true %>
      #
      # variant: is button_classes' (:default, :primary, :ghost, :danger, :icon) and
      # size: :small or :large. href: renders a link; with a method: other than GET
      # it renders button_to, whose options (form:, params:) pass through. icon: is
      # a symbol from the gem's Lucide set or your own markup, and leads the label;
      # the :icon variant shows only the icon and keeps the label for a screen
      # reader and a hover. loading: true disables the button and turns a spinner
      # in the icon's place. disabled: true disables a button, and marks a link
      # aria-disabled and takes it out of the tab order. block: true fills the
      # width. Other options go on the element.
      def button(label = nil, variant = :default, **options, &block)
        Components::ButtonTag.new(self, block ? capture(&block) : label, variant: variant, **options).render
      end

      # Buttons joined edge to edge into one control: a set of views, a pair of
      # steps, a split action.
      #
      #   <%= button_group label: "View" do |group| %>
      #     <% group.button "List", icon: :list_checks %>
      #     <% group.button "Board", icon: :folder %>
      #   <% end %>
      #
      # group.button takes the button helper's arguments; group.item takes anything
      # else that belongs in the run. orientation: :vertical stacks them. label:
      # names the group for a screen reader. Other options go on the group.
      def button_group(label: nil, orientation: :horizontal, **options, &block)
        builder = Components::ButtonGroup.new(self, label: label, orientation: orientation, **options)
        capture(builder, &block)
        builder.render
      end

      # A rule between two things: an <hr>, or with a word on it ("or"), or upright
      # between items in a row.
      #
      #   <%= separator %>
      #   <%= separator "or" %>
      #   <%= separator orientation: :vertical %>
      #
      # Other options go on the element.
      def separator(label = nil, orientation: :horizontal, **options)
        Components::Separator.new(self, label, orientation: orientation, **options).render
      end

      # A bar filled to a fraction of the way.
      #
      #   <%= progress 42 %>
      #   <%= progress 3, max: 8, tone: :good, label: "Uploaded" %>
      #   <%= progress indeterminate: true, label: "Preparing" %>
      #
      # value: out of max: (100). tone: :neutral, :good, :warn, :bad or :info; size:
      # :small, :medium or :large. label: is the accessible name ("Progress"). With
      # indeterminate: true, or no value, the bar sweeps rather than fills. Other
      # options go on the bar.
      def progress(value = nil, max: 100, tone: :neutral, size: :medium, label: nil, indeterminate: false, **options)
        Components::Progress.new(self, value, max: max, tone: tone, size: size, label: label,
          indeterminate: indeterminate, **options).render
      end

      # A ring that turns while something loads.
      #
      #   <%= spinner %>
      #   <%= spinner "Checking DNS…", size: :small %>
      #   <button class="<%= button_classes %>" disabled><%= spinner size: :small, label: false %> Verifying</button>
      #
      # Visible text is the label and sits beside the ring. Otherwise label:
      # ("Loading…") is read but not seen, and label: false makes the ring
      # decorative, for a control that already says what is happening. size:
      # :small, :medium or :large. Other options go on the element.
      def spinner(text = nil, label: nil, size: :medium, **options)
        Components::Spinner.new(self, text, label: label, size: size, **options).render
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
      def modal_link_to(name = nil, options = nil, html_options = nil, side: nil, **html, &block)
        if block
          link_to(name, modal_link_options((options || {}).merge(html), side), &block)
        else
          link_to(name, options, modal_link_options((html_options || {}).merge(html), side))
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
      # larger panel; side: :start or :end opens it as a drawer along that edge
      # (pass the same side: to modal_link_to so the skeleton opens there too);
      # close: false drops the close button; any other option rides on the panel.
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
      # The block is yielded the panel builder, for a footer. side: :start or :end
      # makes it a drawer along that edge of the screen, for filters or a record's
      # details; on a phone every dialog is a sheet from the bottom. Extra options
      # ride on the <dialog>. Needs import "unmagic/components/dialog".
      def dialog_tag(id, title: nil, size: :default, side: :center, close: true, **options, &block)
        builder = Components::Dialog.new(self, title: title, size: size, side: side, close: close)
        panel = builder.render(capture(builder, &block))

        options[:class] = class_names("UnmagicDialogBox", options[:class])
        options[:"data-side"] = side unless side == :center
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
      # nothing inside it should then be a link or button of its own. border: false
      # and background: false take those away, for a card nested in another
      # surface. Other options go on the card.
      #
      # In place of a title, card.header { … } is a bar of your own across the top,
      # ruled off from the body: a row of tabs, a search field, a run of badges.
      # Its options go on the <header>.
      def card(title: nil, href: nil, flush: false, border: true, background: true, **options, &block)
        builder = Components::Card.new(self, title: title, href: href, flush: flush, border: border,
          background: background, **options)
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
      # mono: true sets the title in monospace, for a page whose subject is a path
      # or a filename. The builder's breadcrumbs { |crumbs| … } is the trail of pages
      # above this one, where back: goes.
      # The builder also takes title and description blocks for markup, leading for
      # something before the title, such as an avatar, and trailing for markup
      # beside the title that is already rendered — a status partial, a row of
      # badges a helper returns — which can't go through badge because that would
      # wrap a badge in a badge. Other options go on the <header>.
      def page_header(title: nil, description: nil, back: nil, mono: false, **options, &block)
        builder = Components::PageHeader.new(self, title: title, description: description, back: back, mono: mono, **options)
        builder.render(block ? capture(builder, &block) : nil)
      end

      # A titled run of a page: Files, Metadata, Sources. A small heading with what
      # qualifies it beside it, the button that acts on the run hard right, and the
      # run itself as the block.
      #
      #   <%= section "Files" do |section| %>
      #     <% section.aside { badge "12" } %>
      #     <% section.actions { button "Upload", href: new_upload_path, size: :small } %>
      #     <%= table_for @files do |table| %>...<% end %>
      #   <% end %>
      #
      # spacing: :normal (the default) keeps a run apart from what precedes it,
      # :tight closes it up for the first on a page, :none leaves it to you.
      # heading: is the heading level (:h2). On a narrow screen the actions drop
      # under the heading. Other options go on the <section>.
      def section(title, spacing: :normal, heading: :h2, **options, &block)
        builder = Components::Section.new(self, title, spacing: spacing, heading: heading, **options)
        builder.render(block ? capture(builder, &block) : nil)
      end

      # A row about one thing, wherever a list shows it: its picture on the left,
      # its name over a line about it, and whatever the list wants beside it.
      #
      #   <%= item title: file.name, description: "#{file.content_type} · #{size}", href: file_path(file), mono: true do |item| %>
      #     <% item.media { image_tag file.thumbnail } %>
      #     <% item.meta { badge "Hidden" } %>
      #     <% item.actions { menu … } %>
      #   <% end %>
      #
      # title: and description: are strings, or blocks for markup; media is the
      # picture, meta the flags beside the title, actions the right-hand side, and
      # the block's own output goes under the description. href: makes the title
      # a link whose hit area is the whole row, leaving the actions clickable on
      # their own. mono: true sets the title in monospace, for a filename. Other
      # options go on the row.
      def item(title: nil, description: nil, href: nil, mono: false, **options, &block)
        builder = Components::Item.new(self, title: title, description: description, href: href, mono: mono, **options)
        builder.render(block ? capture(builder, &block) : nil)
      end

      # A chart drawn as inline SVG, with its legend, its tooltips and the same
      # numbers as a table for anybody who can't or won't hover.
      #
      #   <%= chart [ { label: "Spent", values: spend_by_day } ], labels: days, format: :money, title: "Spend" %>
      #   <%= chart series, labels: days, title: "Renders by kiln" %>
      #   <%= chart [ { label: "CPU", values: readings } ], labels: times, type: :line, format: :percent, max: 100,
      #         label_format: ->(time) { time.strftime("%H:%M") } %>
      #
      # labels: are the columns (or the points along a line), in order; each series
      # is { label:, values: } with values keyed by label (or an array in the same
      # order) and an optional total: for the legend. type: :column (stacked where
      # there is more than one series) or :line, where a nil value is a gap.
      # format: :count, :money or :percent says how every number reads. width: is
      # the drawing's own width in its units (720; use 300 for one of three abreast);
      # it scales to its box. max: pins the top of a line's axis. label_format: is
      # how a label reads (dates read as "3 Sep"). legend: false and table: false
      # drop those. Colours come from the stylesheet by slot, one per series, so a
      # series is the same colour on every chart; slot: on a series picks one.
      # Other options go on the <figure>.
      def chart(series, labels:, type: :column, format: :count, title: nil, width: Components::Chart::WIDTH,
        legend: true, table: true, max: nil, label_format: nil, **options)
        Components::Chart.new(self, series, labels: labels, type: type, format: format, title: title, width: width,
          legend: legend, table: table, max: max, label_format: label_format, **options).render
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
      #
      #   <%= empty_state "Import a folder or drop files here.", title: "No files yet", icon: :folder do %>
      #     <%= button "Import", :primary, href: new_import_path %>
      #   <% end %>
      #
      # content is the line that says what's missing; title: a heading above it,
      # icon: a glyph from the gem's Lucide set (or your own markup) above that,
      # and the block the actions that fix it. All go through config.empty_state.
      def empty_state(content = nil, title: nil, icon: nil, **options, &block)
        actions = capture(&block) if block
        Components.configuration.empty_state.call(self, content, title: title, icon: icon, actions: actions, **options)
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

      # A dropdown of actions, on the Popover API: the panel is in the top layer,
      # so no card, cell or scrolling box clips it.
      #
      #   <%= menu do |menu| %>
      #     <% menu.section "Share" %>
      #     <% menu.link "Edit", edit_job_path(@job), icon: :pencil %>
      #     <% menu.item "Rename", data: { unmagic_dialog_open: "rename" } %>
      #     <% menu.disclosure "Move to…" do %>…a small form…<% end %>
      #     <% menu.divider %>
      #     <% menu.button "Delete", job_path(@job), method: :delete, tone: :danger,
      #          form: { data: { turbo_confirm: "Delete this job?" } } %>
      #   <% end %>
      #
      # With no label the trigger is a ⋮ icon button labelled "More actions"; pass
      # one for a text button with a chevron. align: :end (default) lines the panel
      # up with the trigger's right edge, :start with its left. link and button take
      # link_to's and button_to's arguments, plus tone: :danger and icon:; item is a
      # plain button for wiring to something on the page; section heads the items
      # after it; disclosure folds a small form out in place, so the whole exchange
      # happens inside the panel.
      #
      # Without script the trigger still opens and closes the panel, with light
      # dismiss and Escape. The script places the panel against the trigger, keeps
      # it there while open, moves between items with the arrow keys, Home and End,
      # focuses the first item when opened from the keyboard, and closes on choosing
      # an item or a Turbo navigation. On a narrow screen the panel is a sheet along
      # the bottom of the screen. id: names the element and derives the panel's.
      # Other options go on the element. Needs import "unmagic/components/menu".
      def menu(label = nil, align: :end, **options, &block)
        builder = Components::Menu.new(self, label: label, align: align, **options)
        capture(builder, &block)
        builder.render
      end

      # The same panel as menu, opened at the pointer on a right-click or a long
      # press on the element with the given id, or at its corner on Shift+F10.
      #
      #   <%= context_menu for: dom_id(file) do |menu| %>
      #     <% menu.link "Open", file_path(file) %>
      #     <% menu.button "Delete", file_path(file), method: :delete, tone: :danger %>
      #   <% end %>
      #
      # for: is required and can name any element, a table row included; the
      # element itself can sit anywhere. label: names the menu ("Actions"). Keep
      # the items reachable elsewhere too: without script the native context menu
      # shows. Needs import "unmagic/components/menu".
      def context_menu(label: nil, **options, &block)
        region = options.delete(:for) or raise ArgumentError, "context_menu needs for: the id of the element it opens on"
        builder = Components::Menu.new(self, label: label, context: region, **options)
        capture(builder, &block)
        builder.render
      end

      # A small panel of content behind a trigger: a form to rename something, a
      # card about a person. Not a menu (that is menu) and not modal (that is dialog).
      #
      #   <%= popover "Rename", title: "Rename" do |popover| %>
      #     <%= form_with model: @job, builder: Unmagic::Components::FormBuilder do |form| %>
      #       <%= form.field :name, "Name" %>
      #       <% popover.footer { form.submit "Rename" } %>
      #     <% end %>
      #   <% end %>
      #
      # The label is a text trigger with a chevron; popover.trigger { … } is a
      # trigger of your own (an avatar) in its place. title: heads the panel and
      # names it. placement: :bottom or :top, align: :start, :center or :end,
      # size: :wide for a larger panel. The panel is in the top layer, placed by
      # script and kept placed while open; on a narrow screen it is a sheet along
      # the bottom. Fires unmagic-popover:open and :close. Other options go on the
      # element. Needs import "unmagic/components/popover".
      def popover(label = nil, title: nil, placement: :bottom, align: :start, size: :default, **options, &block)
        builder = Components::Popover.new(self, label, title: title, placement: placement, align: align, size: size, **options)
        builder.render(capture(builder, &block))
      end

      # A summary that folds a panel open, on <details>: advanced options under a
      # form, a raw payload under a row.
      #
      #   <%= disclosure "Advanced options" do %>…<% end %>
      #   <%= disclosure open: @delivery.failed? do |d| %>
      #     <% d.summary { safe_join [ "Raw payload", badge("failed", tone: :bad) ], " " } %>
      #     …
      #   <% end %>
      #
      # open: true renders it open. Other options go on the <details>. No script.
      def disclosure(summary = nil, open: false, **options, &block)
        builder = Components::Disclosure.new(self, summary, open: open, **options)
        builder.render(capture(builder, &block))
      end

      # A run of disclosures, and with exclusive: true one open at a time through
      # the platform's own <details name>.
      #
      #   <%= accordion exclusive: true, id: "billing_faq" do |accordion| %>
      #     <% accordion.item "When am I charged?", open: true do %>…<% end %>
      #     <% accordion.item "Can I change plans?" do %>…<% end %>
      #   <% end %>
      #
      # accordion.item takes disclosure's arguments. An empty accordion renders
      # nothing; an exclusive one with two items open raises. No script.
      def accordion(id: nil, exclusive: false, **options, &block)
        builder = Components::Accordion.new(self, id: id, exclusive: exclusive, **options)
        capture(builder, &block)
        builder.render
      end

      # A box that scrolls, with shadows where there is more to see.
      #
      #   <%= scroll_area max_height: "20rem", label: "Pipeline stages" do %>…<% end %>
      #   <%= scroll_area axis: :x do %>…a wide board…<% end %>
      #
      # axis: :y (the default), :x or :both. max_height: is a CSS length, set as
      # the --unmagic-scroll-area-max-height knob; without it the height comes from
      # the layout. label: makes it a named region a keyboard can reach and scroll;
      # pass one whenever the content has no links or buttons of its own.
      # shadows: false drops the edge shadows. Other options go on the <div>.
      # No script.
      def scroll_area(axis: :y, max_height: nil, label: nil, shadows: true, **options, &block)
        Components::ScrollArea.new(self, axis: axis, max_height: max_height, label: label, shadows: shadows, **options)
          .render(capture(&block))
      end

      # The navigation down the side of an app: sections of links with icons and
      # counts, a header and a footer, and a sheet from the edge on a narrow screen.
      #
      #   <%= sidebar id: "app_nav", label: "Main" do |nav| %>
      #     <% nav.header { link_to image_tag("logo.svg", alt: "Acme"), root_path } %>
      #     <% nav.section do |s| %>
      #       <% s.link "Inbox", inbox_path, icon: :messages_square, badge: @unread %>
      #       <% s.link "Files", files_path, icon: :folder %>
      #     <% end %>
      #     <% nav.section "Settings", collapsible: true do |s| %>
      #       <% s.link "Members", members_path %>
      #     <% end %>
      #     <% nav.footer { render "account_menu" } %>
      #   <% end %>
      #
      #   <%# In the top bar, shown only below the breakpoint %>
      #   <%= sidebar_toggle "app_nav" %>
      #
      # The <nav> is a popover: below collapse_below: (:md, :lg or :never) the
      # toggle opens it as a sheet from the edge with no script; above it the
      # stylesheet lays it out inline, so the links are never rendered twice. A
      # link's active: marks the current page (nil falls back to current_page?);
      # icon: is a symbol from the gem's set or markup; badge: a count. Other
      # options go on the element. Needs import "unmagic/components/sidebar".
      def sidebar(id:, label: nil, collapse_below: :lg, **options, &block)
        builder = Components::Sidebar.new(self, id: id, label: label, collapse_below: collapse_below, **options)
        capture(builder, &block)
        builder.render
      end

      # The button that opens a sidebar's sheet, hidden above its breakpoint.
      def sidebar_toggle(id, label: nil, **options)
        label ||= I18n.t("unmagic.components.sidebar.menu", default: "Menu")
        tag.button(Components::Icons.svg(self, :menu), type: "button", popovertarget: id, "aria-controls": id,
          "aria-label": label, title: label, **options,
          class: class_names(Components::Button.classes(:icon), "UnmagicSidebarToggle", options[:class]))
      end

      # The bar across the top of an app: a brand, a run of links and the actions
      # at the end. On a narrow screen the links fold behind a menu button.
      #
      #   <%= navbar label: "Main", sticky: true do |nav| %>
      #     <% nav.brand(root_path) { image_tag "logo.svg", alt: "Acme" } %>
      #     <% nav.link "Jobs", jobs_path, current: current_page?(jobs_path) %>
      #     <% nav.link "Candidates", candidates_path %>
      #     <% nav.actions { menu("Ada") { |menu| … } } %>
      #   <% end %>
      #
      # collapse: :sm, :md (the default), :lg or false is the width below which
      # the links fold. Folding is a <details> and needs no script; the script
      # closes it on Escape, on following a link, on an outside press and when
      # the screen grows. Other options go on the <header>. Needs
      # import "unmagic/components/navbar".
      def navbar(label: nil, sticky: false, collapse: :md, **options, &block)
        builder = Components::Navbar.new(self, label: label, sticky: sticky, collapse: collapse, **options)
        capture(builder, &block)
        builder.render
      end

      # A text input that filters a list of options, outside a form builder.
      #
      #   <%= combobox_tag "owner_id", collection: @members, text: :name, selected: params[:owner_id], placeholder: "Anyone" %>
      #   <%= combobox_tag "label_ids", collection: @labels, text: :name, multiple: true, selected: @issue.label_ids %>
      #   <%= combobox_tag "owner_id", collection: [ @owner ].compact, text: :name, src: search_members_path %>
      #
      # collection: is the options, read with value: (:id) and text: (:to_s), or
      # with src: only what is already selected: the rest is fetched as you type,
      # from an action answering ?q= with combobox_results. min_length: (1) and
      # debounce: (200ms) pace the search. multiple: submits name[] with a chip
      # per choice. A block records rich options, called with (combobox, record).
      # The list is a popover in the top layer, placed by script; arrow keys move,
      # Enter chooses, Escape closes and a status region reads the count. Other
      # options go on the element. Needs import "unmagic/components/combobox".
      def combobox_tag(name, collection: [], value: :id, text: :to_s, multiple: false, selected: nil, **options, &block)
        Components::Combobox.new(self, name, collection: collection, value: value, text: text, multiple: multiple,
          selected: selected, **options).build(&block).render
      end

      # The options a search answers with, for a combobox's src:.
      #
      #   <%= combobox_results @members, text: :name %>
      #
      # On a frame request it wraps itself in the frame the combobox asked
      # through, so the same action answers a direct visit too.
      def combobox_results(collection, value: :id, text: :to_s, **options, &block)
        Components::Combobox.new(self, "results", collection: collection, value: value, text: text, **options).build(&block).results
      end

      # A dialog with a search box over every command in the app, opened with a
      # shortcut. Render it once, in the layout, as modal_frame is.
      #
      #   <%= command_palette src: search_commands_path do |palette| %>
      #     <% palette.group "Go to" do |group| %>
      #       <% group.link "Dashboard", root_path, keywords: "home", shortcut: %w[G D] %>
      #       <% group.link "Issues", issues_path, icon: :list_checks %>
      #     <% end %>
      #     <% palette.group "Actions" do |group| %>
      #       <% group.link "New issue", new_issue_path, data: { turbo_frame: "modal" } %>
      #       <% group.button "Sign out", session_path, method: :delete %>
      #     <% end %>
      #   <% end %>
      #   <%= command_palette_button %>
      #
      # Each command holds a real link or button_to form, so Turbo frames and
      # confirms work as they do anywhere. hotkey: ("mod+k", or false) opens it;
      # src: fetches more commands as you type, from an action answering ?q= with
      # command_palette_results. shortcut: draws kbd hints (display only).
      # Escape clears the query, then closes. Other options go on the element.
      # Needs import "unmagic/components/command_palette".
      def command_palette(id: "command_palette", hotkey: "mod+k", src: nil, min_length: 2, placeholder: nil, **options, &block)
        builder = Components::CommandPalette.new(self, id: id, hotkey: hotkey, src: src, min_length: min_length,
          placeholder: placeholder, **options)
        capture(builder, &block)
        builder.render
      end

      # The visible way in to the command palette, labelled "Search" with the
      # shortcut beside it.
      def command_palette_button(label = nil, dialog: "command_palette", hotkey: "mod+k", **options)
        label ||= I18n.t("unmagic.components.command_palette.button", default: "Search")
        options[:class] = class_names(Components::Button.classes, "UnmagicCommandPaletteButton", options[:class])
        dialog_button(dialog: dialog, **options) do
          safe_join [ Components::Icons.svg(self, :search), tag.span(label), (kbd(hotkey: hotkey, class: "UnmagicCommandPaletteButton__hint") if hotkey) ].compact
        end
      end

      # The commands a search answers with, for a command palette's src:.
      def command_palette_results(**options, &block)
        builder = Components::CommandPalette.new(self, src: "", **options)
        capture(builder, &block)
        builder.results
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
      # reason and takes no panel. active: true picks the first tab shown. icon:
      # leads a label with a symbol from the gem's Lucide set (:folder) or rendered
      # markup from your own icons. Arrow keys, Home and End move between tabs.
      # With an id:, the chosen tab is remembered for the tab's session and survives
      # a morph refresh.
      #
      # style: :segmented (the default) is an inset track with the chosen tab raised
      # out of it. style: :bar is a row of pill tabs with no track, for a bar across
      # a card or a page; on a narrow screen it scrolls sideways rather than wrapping.
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
      def tabs(id: nil, style: :segmented, **options, &block)
        builder = Components::Tabs.new(self, id: id, style: style, **options)
        capture(builder, &block)
        builder.render
      end

      # A card with switcher buttons across its top bar and the open one's content
      # below: a README beside the brief, a file's source beside its preview.
      #
      #   <%= panel id: "notes" do |panel| %>
      #     <% panel.tab "README", icon: :book_open %>
      #     <% panel.tab "Agents", icon: :bot %>
      #     <% panel.panel { markdown @readme } %>
      #     <% panel.panel { markdown @agents } %>
      #   <% end %>
      #
      # The tabs are tabs' own, in the bar style: the same labels, icons, disabled:
      # reasons and active: choice, switched in the page. Give each an href: instead
      # and they are pages of their own: the server draws the open one, the block is
      # its body, and the address names the tab.
      #
      #   <%= panel flush: true do |panel| %>
      #     <% panel.tab "Source", href: file_path(@file, view: :source), active: @view == :source %>
      #     <% panel.tab "Preview", href: file_path(@file, view: :preview), active: @view == :preview %>
      #     <%= render "files/#{@view}", file: @file %>
      #   <% end %>
      #
      # flush: true drops the body's padding, for a code view or a table that runs
      # to the edges. Other options go on the outer element. Needs
      # import "unmagic/components/tabs" for in-page tabs.
      def panel(id: nil, flush: false, **options, &block)
        builder = Components::Panel.new(self, id: id, flush: flush, **options)
        builder.render(capture(builder, &block))
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

      # A block of source to read or copy: a file, a payload, a command to paste.
      # Coloured with Rouge, wrapping long lines, with a copy button in the corner.
      #
      #   <%= code_view @file.source, language: @file.language %>
      #   <%= code_view backtrace, language: :plaintext, lines: true, max_height: "20rem" %>
      #   <%= code_view language: :shell, wrap: false, copy: false do %>
      #     bin/rails db:prepare
      #   <% end %>
      #
      # The source is the string, or the block's text with its indentation taken
      # off, for a snippet written into the template (escape a tag as <%%).
      # language: is a name Rouge knows (:json, "ruby", :erb) or a lexer; unknown or
      # nil is plain text. lines: true numbers the lines (the numbers are drawn, so a
      # copy leaves them behind). wrap: false scrolls sideways instead of wrapping.
      # max_height: is a CSS length past which the block scrolls; a block that can
      # scroll is focusable and named label: ("Code") for a keyboard. copy: false
      # drops the button. id: names the wrapper; the <code> is "#{id}_code". Other
      # options go on the wrapper. Colouring goes through config.highlight.
      # Needs import "unmagic/components/clipboard" for the button.
      def code_view(source = nil, language: nil, lines: false, wrap: true, max_height: nil, copy: true, label: nil,
        id: nil, **options, &block)
        source = Components::CodeView.snippet(capture(&block)) if block

        Components::CodeView.new(self, source, language: language, lines: lines, wrap: wrap, max_height: max_height,
          copy: copy, label: label, id: id, **options).render
      end

      # text_area_tag, growing with its content. See FormBuilder#autogrow_text_area.
      def autogrow_text_area_tag(name, content = nil, **options)
        Components::Autogrow.wrap(self, text_area_tag(name, content, Components::Control.merge(self, options, :text_area)))
      end

      # A checkbox drawn as a switch, outside a form builder. With label: it
      # renders the labelled layout. See FormBuilder#switch_field.
      def switch_tag(name, value = "1", checked: false, label: nil, hint: nil, **options)
        input = check_box_tag(name, value, checked, Components::Control.merge(self, options.merge(role: "switch"), :switch))
        return input unless label

        content_tag(:label, class: class_names("UnmagicCheckField UnmagicCheckField--switch", "UnmagicCheckField--hinted" => hint)) do
          safe_join [
            input,
            content_tag(:span, class: "UnmagicCheckField__text") do
              safe_join [ content_tag(:span, label, class: "UnmagicCheckField__label"), (content_tag(:span, hint, class: "UnmagicHint") if hint) ].compact
            end
          ]
        end
      end

      # password_field_tag with the gem's look, and with reveal: true a button that
      # shows what was typed. See FormBuilder#password_field.
      def password_field_tag(name = "password", value = nil, options = {})
        options = options.dup
        reveal = options.delete(:reveal)
        id = options[:id] || sanitize_to_id(name)
        input = super(name, value, Components::Control.merge(self, options.merge(id: id), :password))
        reveal ? Components::Password.wrap(self, input, id: id) : input
      end

      # One input for a code sent by SMS or email, outside a form builder. See
      # FormBuilder#one_time_code_field.
      def one_time_code_field_tag(name, value = nil, length: 6, charset: :numeric, submit: false, **options)
        options = Components::OneTimeCode.input_options(options, length: length, charset: charset)
        classes = class_names("UnmagicOneTimeCode__input", Components::Control.merge(self, options, :one_time_code)[:class])
        input = text_field_tag(name, value, options.merge(class: classes))
        Components::OneTimeCode.wrap(self, input, length: length, charset: charset, submit: submit)
      end

      # A control with something joined to either end: a unit, a scheme, a button.
      #
      #   <%= input_group prefix: "https://", suffix: ".example.com" do %>
      #     <%= form.text_field :subdomain %>
      #   <% end %>
      #   <%= input_group suffix: button("Search", type: "submit") do %>
      #     <%= search_field_tag :q, params[:q], class: control_classes(:input) %>
      #   <% end %>
      #
      # Text becomes a tinted addon; markup (a button, an icon) is set in as it is.
      # The block is the control. Other options go on the group.
      def input_group(prefix: nil, suffix: nil, **options, &block)
        Components::InputGroup.new(self, prefix: prefix, suffix: suffix, **options).render(capture(&block))
      end

      # A button that is on or off: bold, wrap lines, show archived.
      #
      #   <%= toggle "Bold", icon: :pencil, pressed: true %>
      #   <%= toggle "Show archived", name: "archived", pressed: params[:archived] %>
      #
      # With a name: it is a checkbox drawn as a button, so a form submits it and
      # no script is needed. Without one it is a button with aria-pressed, which
      # import "unmagic/components/toggle" flips on click (firing
      # unmagic-toggle:change). icon: leads the label; icon_only: true keeps the
      # label for a screen reader. size: :small or :large. Other options go on
      # the element.
      def toggle(label, pressed: false, icon: nil, name: nil, value: "1", size: nil, disabled: false, **options)
        Components::Toggle.new(self, label, pressed: pressed, icon: icon, name: name, value: value, size: size,
          disabled: disabled, **options).render
      end

      # A choice of one, or with multiple: true several, as a run of joined
      # toggles: a segmented control a form submits.
      #
      #   <%= toggle_group name: "range", value: params[:range] || "7d", label: "Range" do |group| %>
      #     <% group.option "24 hours", "24h" %>
      #     <% group.option "7 days", "7d" %>
      #     <% group.option "30 days", "30d" %>
      #   <% end %>
      #
      # Native radios (or checkboxes) drawn as buttons: the arrow keys move the
      # choice, and no script is needed. group.option takes a label, a value, and
      # an icon:. label: names the group. size: :small or :large. Other options go
      # on the group. For links to pages, use tabs with href:.
      def toggle_group(name:, value: nil, multiple: false, label: nil, size: nil, **options, &block)
        builder = Components::ToggleGroup.new(self, name: name, value: value, multiple: multiple, label: label, size: size, **options)
        capture(builder, &block)
        builder.render
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
      # id: selects a stream target; position: defaults to :top_end (see Toast::POSITIONS).
      # scoped: true contains toasts in the nearest positioned ancestor.
      # Other options go on <unmagic-toasts>.
      def flash_toasts(flashes = flash, duration: 5000, **options)
        Components::Toasts.new(self, flashes, duration: duration, **options).render
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
      # level (:h2). Other options go on the root. With an id:, import
      # "unmagic/components/ai_chat" keeps a person's open or shut across
      # broadcasts; open: then only decides until they choose.
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
      # Give it paths and it draws them as a tree_view of folders, open, with
      # folders ahead of the files beside them; a folder that holds only one
      # folder joins it in a single row (captures/example.com/jobs). url: makes a
      # file a link, size: shows beside it, and icon: changes its glyph, which is
      # otherwise picked from the extension (:file_code, :file_text, :file_image,
      # …, or :file). Each row's title is its full path. The count is the number
      # of files. Takes ai_chat_plan's title:, count:, open:, empty:,
      # collapsible: and title_tag:, and keeps a person's open or shut the same
      # way. Other options go on the root.
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

      def modal_link_options(html_options, side = nil)
        html_options = (html_options || {}).dup
        data = { turbo_frame: Components.configuration.modal_frame_id }
        data[:unmagic_modal_side] = side if side && side.to_sym != :center
        html_options[:data] = data.merge(html_options[:data] || {})
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
