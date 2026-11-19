# frozen_string_literal: true

class TeamInvitationSerializer < ApplicationSerializer
  typelize_from Invitation

  attributes :code, :email, :role, :created_at
end
