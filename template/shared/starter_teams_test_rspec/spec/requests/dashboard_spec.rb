# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  fixtures :users, :teams, :memberships

  before { sign_in users(:two) }

  describe "GET /dashboard" do
    it "redirects to the current team" do
      get dashboard_path
      expect(response).to redirect_to(team_dashboard_path(teams(:two_personal)))
    end
  end

  describe "GET /:team_id/dashboard" do
    it "renders the dashboard and makes the team current" do
      get team_dashboard_path(teams(:acme))
      expect(response).to have_http_status(:success)
      expect(users(:two).reload.current_team).to eq(teams(:acme))
    end

    it "is not found for a team the user does not belong to" do
      get team_dashboard_path(teams(:one_personal))
      expect(response).to have_http_status(:not_found)
    end
  end
end
