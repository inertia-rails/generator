# frozen_string_literal: true

class DashboardShowSerializer < ApplicationSerializer
  has_many :pending_invitations, resource: PendingInvitationSerializer
end
