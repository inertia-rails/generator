# frozen_string_literal: true

# Invitations the current user has received
class InvitationsController < InertiaController
  before_action :set_invitation

  def accept
    @invitation.accept!(Current.user)

    redirect_to team_dashboard_path(@invitation.team), notice: "You joined #{@invitation.team.name}"
  end

  def destroy
    @invitation.destroy!

    redirect_to dashboard_path, notice: "Invitation declined"
  end

  private

  def set_invitation
    @invitation = Current.user.pending_invitations.find_by!(code: params[:code])
  end
end
