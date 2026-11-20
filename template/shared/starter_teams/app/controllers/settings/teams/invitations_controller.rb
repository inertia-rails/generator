# frozen_string_literal: true

# Invitations a team has sent
class Settings::Teams::InvitationsController < InertiaController
  before_action :set_team

  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to settings_team_path(@team), alert: "Too many attempts. Try again later" }

  def create
    invitation = @team.invitations.new(email: params[:email], role: params[:role], invited_by: Current.user)

    if invitation.save
      TeamMailer.with(invitation: invitation).invitation.deliver_later
      redirect_to settings_team_path(@team), notice: "Invitation sent"
    else
      redirect_to settings_team_path(@team), inertia: { errors: invitation.errors }
    end
  end

  def destroy
    @team.invitations.find_by!(code: params[:code]).destroy!

    redirect_to settings_team_path(@team), notice: "Invitation cancelled"
  end

  private

  def set_team
    @team = Current.user.teams.find_by!(slug: params[:team_slug])
    authorize! @team, to: :invite?
  end
end
