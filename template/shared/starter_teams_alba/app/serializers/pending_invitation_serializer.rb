# frozen_string_literal: true

class PendingInvitationSerializer < ApplicationSerializer
  typelize_from Invitation

  attributes :code

  typelize :string
  attribute :team_name do |invitation|
    invitation.team.name
  end

  typelize :string
  attribute :invited_by do |invitation|
    invitation.invited_by.name
  end
end
