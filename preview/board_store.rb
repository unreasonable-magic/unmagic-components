# frozen_string_literal: true

require "securerandom"

module ComponentsPreview
  # The board example's data, kept in the session. It takes drops the way
  # unmagic-sortable's endpoint does — moved, prev, next and the column — with
  # float ranks, which are plenty for one person's session.
  class BoardStore
    COLUMNS = [ %w[todo To\ do], %w[doing Doing], %w[review Review], %w[done Done] ].freeze

    CARDS = [
      [ "todo", "Write the job ad for the platform role", "Hiring", "Ada Lovelace" ],
      [ "todo", "Book the room for Thursday's panel", "Ops", nil ],
      [ "todo", "Ask Grace for interview feedback", "Hiring", "Grace Hopper" ],
      [ "doing", "Shortlist the backend candidates", "Hiring", "Katherine Johnson" ],
      [ "doing", "Draft the offer letter template", "Legal", "Alan Turing" ],
      [ "review", "Check the salary bands against the market", "Finance", "Margaret Hamilton" ],
      [ "done", "Post the role on the careers page", "Hiring", "Ada Lovelace" ],
      [ "done", "Set up the take-home repository", "Eng", "Dennis Ritchie" ]
    ].freeze

    def initialize(session)
      @session = session
      @session[:board] ||= seed
    end

    def columns = data["columns"].sort_by { |column| column["rank"] }

    def cards_in(column)
      data["cards"].select { |card| card["column"] == column["key"] }.sort_by { |card| card["rank"] }
    end

    def move(key, prev:, following:, column: nil)
      record = (data["columns"] + data["cards"]).find { |item| item["key"] == key }
      return false unless record

      record["rank"] = between(prev.presence&.to_f, following.presence&.to_f)
      record["column"] = column if column.present? && record.key?("column")
      true
    end

    # The session is a cookie, so the board stays small enough to fit in one.
    LIMIT = 30

    def add_card(title, column)
      return if title.blank? || data["cards"].size >= LIMIT || data["columns"].none? { |c| c["key"] == column }

      last = data["cards"].select { |card| card["column"] == column }.map { |card| card["rank"] }.max
      data["cards"] << { "key" => "card-#{SecureRandom.hex(3)}", "title" => title.strip, "column" => column,
                         "tag" => nil, "owner" => nil, "rank" => between(last, nil) }
    end

    def add_column(title)
      return if title.blank? || data["columns"].size >= 8

      last = data["columns"].map { |column| column["rank"] }.max
      data["columns"] << { "key" => "column-#{SecureRandom.hex(3)}", "title" => title.strip, "rank" => between(last, nil) }
    end

    def reset! = @session[:board] = seed

    private

    def data = @session[:board]

    def between(lower, upper)
      if lower && upper then (lower + upper) / 2
      elsif upper then upper - 1
      elsif lower then lower + 1
      else 1.0
      end
    end

    def seed
      {
        "columns" => COLUMNS.each_with_index.map { |(key, title), index| { "key" => key, "title" => title, "rank" => index + 1.0 } },
        "cards" => CARDS.each_with_index.map do |(column, title, tag, owner), index|
          { "key" => "card-#{index + 1}", "title" => title, "column" => column, "tag" => tag, "owner" => owner, "rank" => index + 1.0 }
        end
      }
    end
  end
end
