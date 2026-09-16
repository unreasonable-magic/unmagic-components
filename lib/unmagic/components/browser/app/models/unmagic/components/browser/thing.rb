# frozen_string_literal: true

require "active_model"

module Unmagic
  module Components
    module Browser
      # A row for the preview tables. Not an Active Record — the preview has no
      # database — but enough of a model for dom_id.
      class Thing
        include ActiveModel::Model
        include ActiveModel::Conversion
        extend ActiveModel::Naming

        attr_accessor :id, :name, :role, :score, :note

        def to_key = [ id ]
        def persisted? = id.present?

        def self.all
          [
            new(id: 1, name: "Ada Lovelace", role: "Engineer", score: 120, note: "Replied: happy to chat next week."),
            new(id: 2, name: "Grace Hopper", role: "Engineer", score: 98),
            new(id: 3, name: "Katherine Johnson", role: "Analyst", score: 87),
            new(id: 4, name: "Radia Perlman", role: "Architect", score: 64)
          ]
        end
      end
    end
  end
end
