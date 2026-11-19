# frozen_string_literal: true

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  setup do
    sign_in users(:two)
  end

  test "redirects to the current team" do
    get dashboard_path
    assert_redirected_to team_dashboard_path(teams(:two_personal))
  end

  test "renders the dashboard and makes the team current" do
    get team_dashboard_path(teams(:acme))
    assert_response :success
    assert_equal teams(:acme), users(:two).reload.current_team
  end

  test "is not found for a team the user does not belong to" do
    get team_dashboard_path(teams(:one_personal))
    assert_response :not_found
  end
end
