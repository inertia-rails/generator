# frozen_string_literal: true

class SessionsNewSerializer < ApplicationSerializer
  one :team_invitation, resource: TeamInvitationContextSerializer
  typelize team_invitation: [ TeamInvitationContextSerializer, nullable: true ]
end
