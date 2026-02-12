# frozen_string_literal: true

class UserSerializer < ApplicationSerializer
  attributes :id, :name, :email, :verified, :created_at, :updated_at

  typelize :string?
  attribute :avatar do |user|
    nil # Placeholder for avatar URL (e.g. Gravatar, Active Storage)
  end
end
