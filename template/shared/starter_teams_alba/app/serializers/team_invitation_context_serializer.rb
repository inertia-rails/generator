# frozen_string_literal: true

# The invitation a guest arrives with on the sign in and sign up pages
# (see ApplicationController#team_invitation)
class TeamInvitationContextSerializer < ApplicationSerializer
  attributes :code, :team_name
  typelize code: :string, team_name: :string
end
