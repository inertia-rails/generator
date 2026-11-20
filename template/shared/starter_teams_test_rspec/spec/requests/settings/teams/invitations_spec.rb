# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Teams::Invitations", type: :request do
  fixtures :users, :teams, :memberships

  let(:team) { teams(:acme) }

  describe "POST /settings/teams/:team_slug/invitations" do
    it "invites someone by email" do
      sign_in users(:one)

      expect {
        post settings_team_invitations_path(team), params: { email: "New@Example.com", role: "admin" }
      }.to have_enqueued_mail(TeamMailer, :invitation)

      expect(response).to redirect_to(settings_team_path(team))
      expect(team.invitations.pending.last).to have_attributes(email: "new@example.com", role: "admin")
    end

    it "rejects someone who is already a member" do
      sign_in users(:one)
      post settings_team_invitations_path(team), params: { email: "two@example.com", role: "member" }
      expect(session[:inertia_errors]).to eq(email: [ "is already a member of the team" ])
    end

    it "is not allowed for a member" do
      sign_in users(:two)

      expect {
        post settings_team_invitations_path(team), params: { email: "new@example.com", role: "member" }
      }.not_to change(Invitation, :count)
      expect(flash[:alert]).to eq("You are not allowed to do that")
    end
  end

  describe "DELETE /settings/teams/:team_slug/invitations/:code" do
    it "cancels the invitation" do
      sign_in users(:one)
      invitation = team.invitations.create!(email: "new@example.com", role: "member", invited_by: users(:one))

      delete settings_team_invitation_path(team, invitation)
      expect(response).to redirect_to(settings_team_path(team))
      expect(Invitation.exists?(invitation.id)).to be(false)
    end
  end
end
