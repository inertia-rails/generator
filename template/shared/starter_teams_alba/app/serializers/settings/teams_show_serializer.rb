# frozen_string_literal: true

module Settings
  class TeamsShowSerializer < ApplicationSerializer
    one :team, resource: TeamSerializer
    has_many :members, resource: TeamMemberSerializer
    has_many :invitations, resource: TeamInvitationSerializer
    one :permissions, resource: TeamPermissionsSerializer

    attributes :assignable_roles, :invitation_roles
    typelize assignable_roles: [ :MembershipRole, multi: true ], invitation_roles: [ :MembershipRole, multi: true ]
  end
end
