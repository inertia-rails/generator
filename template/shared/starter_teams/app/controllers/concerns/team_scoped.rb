# frozen_string_literal: true

# For pages that belong to a team. Their URLs carry the team (/:team_slug/...),
# so links, bookmarks and browser tabs keep pointing at the same team.
module TeamScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_team
  end

  private

  def set_team
    @team = Current.user.teams.find_by!(slug: params[:team_slug])

    # Opening a team's page makes it the current team
    Current.user.update!(current_team: @team) unless Current.user.current_team_id == @team.id
  end
end
