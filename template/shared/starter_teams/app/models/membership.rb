# frozen_string_literal: true

class Membership < ApplicationRecord
  # Roles that can be assigned when editing an existing member
  ASSIGNABLE_ROLES = %w[admin member].freeze

  belongs_to :team
  belongs_to :user

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }

  # A former member cannot keep working in the team
  after_destroy do
    User.where(id: user_id, current_team_id: team_id).update_all(current_team_id: nil)
  end
end
