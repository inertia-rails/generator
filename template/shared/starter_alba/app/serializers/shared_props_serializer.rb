# frozen_string_literal: true

class SharedPropsSerializer < ApplicationSerializer
  one :auth, source: proc { Current }
<% if use_teams %>
  one :current_team, source: proc { Current.user&.current_team }, resource: TeamSerializer
  typelize current_team: [ TeamSerializer, nullable: true ]
  many :teams, source: proc { Current.user&.teams_with_roles || [] }, resource: TeamSerializer
<% end %>
end
