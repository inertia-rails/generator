# frozen_string_literal: true

class TeamMemberSerializer < ApplicationSerializer
  typelize_from Membership

  attributes :id, :role

  typelize :string
  attribute :name do |membership|
    membership.user.name
  end

  typelize :string
  attribute :email do |membership|
    membership.user.email
  end

  typelize :string?
  attribute :avatar do |membership|
    nil # Placeholder for avatar URL (e.g. Gravatar, Active Storage)
  end
end
