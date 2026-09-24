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

        attr_accessor :id, :name, :role, :score, :note, :company, :status, :skills

        def to_key = [ id ]
        def email = "#{name.to_s.split.first.to_s.downcase}@example.com"
        def persisted? = id.present?

        def self.all
          [
            new(id: 1, name: "Ada Lovelace", role: "Engineer", score: 120, note: "Replied: happy to chat next week.",
                company: "Analytical Engines", status: "Interviewing", skills: %w[Maths Rust]),
            new(id: 2, name: "Grace Hopper", role: "Engineer", score: 98,
                company: "Harvard Computation Lab", status: "Placed", skills: %w[COBOL Compilers Navy]),
            new(id: 3, name: "Katherine Johnson", role: "Analyst", score: 87,
                company: "NASA Langley", status: "Placed", skills: %w[Orbits Fortran]),
            new(id: 4, name: "Radia Perlman", role: "Architect", score: 64,
                company: "Digital Equipment", status: "Sourced", skills: %w[Networks Routing Security])
          ]
        end
      end
    end
  end
end
