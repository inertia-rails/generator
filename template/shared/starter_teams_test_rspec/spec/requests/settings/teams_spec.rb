# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Teams", type: :request do
  fixtures :users, :teams, :memberships

  let(:team) { teams(:acme) }

  describe "GET /settings/teams" do
    it "renders the teams page" do
      sign_in users(:one)
      get settings_teams_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /settings/teams" do
    before { sign_in users(:one) }

    it "creates a team owned by the user and makes it current" do
      expect {
        post settings_teams_path, params: { name: "New Team" }
      }.to change(Team, :count).by(1)

      team = Team.find_by!(name: "New Team")
      expect(response).to redirect_to(settings_team_path(team))
      expect(team.owner).to eq(users(:one))
      expect(users(:one).reload.current_team).to eq(team)
    end

    it "routes teams with the same name independently" do
      post settings_teams_path, params: { name: team.name }
      created = users(:one).reload.current_team
      expect(created.id).not_to eq(team.id)
      expect(created.to_param).to eq("#{created.id}-acme")
      expect(response).to redirect_to(settings_team_path(created))
    end
  end

  describe "GET /settings/teams/:id" do
    it "renders the team page for a member" do
      sign_in users(:two)
      get settings_team_path(team)
      expect(response).to have_http_status(:success)
    end

    it "is not found for a team the user does not belong to" do
      sign_in users(:two)
      get settings_team_path(teams(:one_personal))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /settings/teams/:id" do
    it "renames the team and keeps its old dashboard URL working" do
      sign_in users(:one)
      bookmark = team_dashboard_path(team)
      patch settings_team_path(team), params: { name: "Acme Corp" }
      expect(response).to redirect_to(settings_team_path("#{team.id}-acme-corp"))
      get bookmark
      expect(response).to have_http_status(:success)
      expect(users(:one).reload.current_team).to eq(team)
    end

    it "is not allowed for a member" do
      sign_in users(:two)
      patch settings_team_path(team), params: { name: "Acme Corp" }
      expect(flash[:alert]).to eq("You are not allowed to do that")
      expect(team.reload.name).to eq("Acme")
    end
  end

  describe "DELETE /settings/teams/:id" do
    before { sign_in users(:one) }

    it "deletes the team when the name is confirmed" do
      users(:two).update!(current_team: team)

      expect {
        delete settings_team_path(team), params: { name: "Acme" }
      }.to change(Team, :count).by(-1)
      expect(response).to redirect_to(settings_teams_path)
      expect(users(:two).reload.current_team).to eq(teams(:two_personal))
    end

    it "keeps the team when the name does not match" do
      expect {
        delete settings_team_path(team), params: { name: "Wrong" }
      }.not_to change(Team, :count)
      expect(session[:inertia_errors]).to eq(name: [ "does not match the team name" ])
    end

    it "is not allowed for a personal team" do
      expect {
        delete settings_team_path(teams(:one_personal)), params: { name: "Test User's Team" }
      }.not_to change(Team, :count)
    end
  end

  describe "DELETE /settings/teams/:id/leave" do
    it "removes the member from the team" do
      sign_in users(:two)
      delete leave_settings_team_path(team)
      expect(response).to redirect_to(settings_teams_path)
      expect(team.members).not_to include(users(:two))
    end

    it "is not allowed for the owner" do
      sign_in users(:one)
      delete leave_settings_team_path(team)
      expect(team.members).to include(users(:one))
    end
  end
end
