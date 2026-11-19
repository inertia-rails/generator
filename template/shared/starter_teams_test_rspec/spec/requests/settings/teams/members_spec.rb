# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Teams::Members", type: :request do
  fixtures :users, :teams, :memberships

  let(:team) { teams(:acme) }
  let(:membership) { memberships(:acme_member) }

  describe "PATCH /settings/teams/:team_slug/members/:id" do
    it "changes the member's role" do
      sign_in users(:one)
      patch settings_team_member_path(team, membership), params: { role: "admin" }
      expect(response).to redirect_to(settings_team_path(team))
      expect(membership.reload).to be_admin
    end

    it "cannot make someone an owner" do
      sign_in users(:one)
      patch settings_team_member_path(team, membership), params: { role: "owner" }
      expect(membership.reload).to be_member
    end

    it "is not allowed for a member" do
      sign_in users(:two)
      patch settings_team_member_path(team, membership), params: { role: "admin" }
      expect(flash[:alert]).to eq("You are not allowed to do that")
      expect(membership.reload).to be_member
    end
  end

  describe "DELETE /settings/teams/:team_slug/members/:id" do
    before { sign_in users(:one) }

    it "removes the member" do
      delete settings_team_member_path(team, membership)
      expect(response).to redirect_to(settings_team_path(team))
      expect(team.members).not_to include(users(:two))
    end

    it "cannot remove the owner" do
      delete settings_team_member_path(team, memberships(:acme_owner))
      expect(response).to have_http_status(:not_found)
    end
  end
end
