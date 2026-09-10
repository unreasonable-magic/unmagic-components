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

      private

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
