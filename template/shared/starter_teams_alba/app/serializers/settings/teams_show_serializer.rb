# frozen_string_literal: true

module Settings
  class TeamsShowSerializer < ApplicationSerializer
    one :team, resource: TeamSerializer
    has_many :members, resource: TeamMemberSerializer
    has_many :invitations, resource: TeamInvitationSerializer

    attributes :assignable_roles, :permissions
    typelize assignable_roles: "Array<'admin' | 'member'>",
      permissions: "Record<'update' | 'destroy' | 'invite' | 'update_member' | 'remove_member', boolean>"
  end
end
