# frozen_string_literal: true

require "active_model"

module Unmagic
  module Components
    module Browser
      # What the dialog preview edits: one validated field, kept in the session so a
      # save visibly changes the page the modal was opened from.
      class Profile
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :name, :string
        attribute :role, :string
        attribute :notify, :boolean, default: true
        attribute :two_factor, :boolean, default: false
        attribute :volume, :integer, default: 40
        attribute :password, :string
        attribute :code, :string

        validates :name, presence: true

        def self.model_name = ActiveModel::Name.new(self, nil, "Profile")

        def persisted? = true
      end
    end
  end
end
