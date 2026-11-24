# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations", type: :request do
  fixtures :users, :teams, :memberships

  let(:invitation) do
    teams(:one_personal).invitations.create!(email: "two@example.com", role: "admin", invited_by: users(:one))
  end

  before { sign_in users(:two) }

  describe "POST /invitations/:code/accept" do
    it "adds the user to the team" do
      post accept_invitation_path(invitation)
      expect(response).to redirect_to(team_dashboard_path(teams(:one_personal)))
      expect(teams(:one_personal).memberships.find_by!(user: users(:two))).to be_admin
      expect(users(:two).reload.current_team).to eq(teams(:one_personal))
    end

    it "grants ownership when an owner invitation is accepted" do
      invitation.update!(role: :owner)
      post accept_invitation_path(invitation)

      expect(invitation.team.memberships.find_by!(user: users(:two))).to be_owner
    end

    it "is not found once the invitation has expired" do
      invitation.update!(expires_at: 1.minute.ago)
      post accept_invitation_path(invitation)
      expect(response).to have_http_status(:not_found)
    end

    it "is not found when the invitation was sent to someone else" do
      invitation.update!(email: "someone@example.com")
      post accept_invitation_path(invitation)
      expect(response).to have_http_status(:not_found)
    end

    it "is not found until the user has verified their email" do
      users(:two).update!(verified: false)
      post accept_invitation_path(invitation)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /invitations/:code" do
    it "declines the invitation" do
      delete invitation_path(invitation)
      expect(response).to redirect_to(dashboard_path)
      expect(Invitation.exists?(invitation.id)).to be(false)
    end
  end
end
