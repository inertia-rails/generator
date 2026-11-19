# frozen_string_literal: true

class UsersNewSerializer < ApplicationSerializer
  attributes :team_invitation
  typelize team_invitation: "{ code: string; team_name: string } | null"
end
