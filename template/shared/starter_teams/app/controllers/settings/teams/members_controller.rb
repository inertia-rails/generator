# frozen_string_literal: true

class Settings::Teams::MembersController < InertiaController
  before_action :set_team
  before_action :set_membership

  def update
    authorize! @team, to: :update_member?

    if Membership::ASSIGNABLE_ROLES.include?(params[:role]) && @membership.update(role: params[:role])
      redirect_to settings_team_path(@team), notice: "Member role updated"
    else
      redirect_to settings_team_path(@team), alert: "That role cannot be assigned"
    end
  end

  def destroy
    authorize! @team, to: :remove_member?

    @membership.destroy!

    redirect_to settings_team_path(@team), notice: "Member removed"
  end

  private

  def set_team
    @team = Current.user.teams.find(params[:team_id])
  end

  # The owner's membership cannot be changed or removed
  def set_membership
    @membership = @team.memberships.where(role: Membership::ASSIGNABLE_ROLES).find(params[:id])
  end
end
