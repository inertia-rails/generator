# frozen_string_literal: true

class UsersNewSerializer < ApplicationSerializer
  one :team_invitation, resource: TeamInvitationContextSerializer
  typelize team_invitation: [ TeamInvitationContextSerializer, nullable: true ]
end
