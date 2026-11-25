# frozen_string_literal: true

# What the current user can do with a team (see Settings::TeamsController#team_permissions)
class TeamPermissionsSerializer < ApplicationSerializer
  attributes :update, :destroy, :invite, :update_member, :remove_member
  typelize update: :boolean, destroy: :boolean, invite: :boolean, update_member: :boolean, remove_member: :boolean
end
