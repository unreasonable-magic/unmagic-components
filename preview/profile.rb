# frozen_string_literal: true

module ComponentsPreview
  # What the dialog preview edits: one validated field, kept in the session so a
  # save visibly changes the page the modal was opened from.
  class Profile
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :role, :string

    validates :name, presence: true

    def self.model_name = ActiveModel::Name.new(self, nil, "Profile")

    def persisted? = true
  end
end
