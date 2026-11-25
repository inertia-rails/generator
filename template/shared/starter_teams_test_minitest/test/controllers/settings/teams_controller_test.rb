# frozen_string_literal: true

require "test_helper"

class Settings::TeamsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  setup do
    @team = teams(:acme)
  end

  test "renders the teams page" do
    sign_in users(:one)
    get settings_teams_path
    assert_response :success
  end

  test "creates a team owned by the user and makes it current" do
    sign_in users(:one)
    assert_difference "Team.count", 1 do
      post settings_teams_path, params: { name: "New Team" }
    end

    team = Team.find_by!(name: "New Team")
    assert_redirected_to settings_team_path(team)
    assert_equal users(:one), team.owner
    assert_equal team, users(:one).reload.current_team
  end

  test "routes teams with the same name independently" do
    sign_in users(:one)
    post settings_teams_path, params: { name: @team.name }
    created = users(:one).reload.current_team
    assert_not_equal @team.id, created.id
    assert_equal "#{created.id}-acme", created.to_param
    assert_redirected_to settings_team_path(created)
  end

  test "renders the team page for a member" do
    sign_in users(:two)
    get settings_team_path(@team)
    assert_response :success
  end

  test "is not found for a team the user does not belong to" do
    sign_in users(:two)
    get settings_team_path(teams(:one_personal))
    assert_response :not_found
  end

  test "renames the team and keeps its old dashboard URL working" do
    sign_in users(:one)
    bookmark = team_dashboard_path(@team)
    patch settings_team_path(@team), params: { name: "Acme Corp" }
    assert_redirected_to settings_team_path("#{@team.id}-acme-corp")
    get bookmark
    assert_response :success
    assert_equal @team, users(:one).reload.current_team
  end

  test "renaming is not allowed for a member" do
    sign_in users(:two)
    patch settings_team_path(@team), params: { name: "Acme Corp" }
    assert_equal "You are not allowed to do that", flash[:alert]
    assert_equal "Acme", @team.reload.name
  end

  test "deletes the team when the name is confirmed" do
    sign_in users(:one)
    users(:two).update!(current_team: @team)

    assert_difference "Team.count", -1 do
      delete settings_team_path(@team), params: { name: "Acme" }
    end
    assert_redirected_to settings_teams_path
    assert_equal teams(:two_personal), users(:two).reload.current_team
  end

  test "keeps the team when the name does not match" do
    sign_in users(:one)
    assert_no_difference "Team.count" do
      delete settings_team_path(@team), params: { name: "Wrong" }
    end
    assert_equal({ name: [ "does not match the team name" ] }, session[:inertia_errors])
  end

  test "deleting is not allowed for a personal team" do
    sign_in users(:one)
    assert_no_difference "Team.count" do
      delete settings_team_path(teams(:one_personal)), params: { name: "Test User's Team" }
    end
  end

  test "leaving removes the member from the team" do
    sign_in users(:two)
    delete leave_settings_team_path(@team)
    assert_redirected_to settings_teams_path
    assert_not_includes @team.members, users(:two)
  end

  test "leaving is not allowed for the owner" do
    sign_in users(:one)
    delete leave_settings_team_path(@team)
    assert_includes @team.members, users(:one)
  end
end
