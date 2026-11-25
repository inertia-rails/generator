# frozen_string_literal: true

class TeamSerializer < ApplicationSerializer
  attributes :id, :name, :personal, :to_param
  typelize to_param: :string

  # The current user's role, when the team was loaded with it (see User#teams_with_roles)
  typelize :MembershipRole, optional: true
  attribute :role, if: proc { |team| team.has_attribute?(:role) } do |team|
    team[:role]
  end
end
