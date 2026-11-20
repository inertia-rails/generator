# frozen_string_literal: true

require "test_helper"

class Settings::Teams::MembersControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  setup do
    @team = teams(:acme)
    @membership = memberships(:acme_member)
  end

  test "changes the member's role" do
    sign_in users(:one)
    patch settings_team_member_path(@team, @membership), params: { role: "admin" }
    assert_redirected_to settings_team_path(@team)
    assert_predicate @membership.reload, :admin?
  end

  test "cannot make someone an owner" do
    sign_in users(:one)
    patch settings_team_member_path(@team, @membership), params: { role: "owner" }
    assert_predicate @membership.reload, :member?
  end

  test "changing a role is not allowed for a member" do
    sign_in users(:two)
    patch settings_team_member_path(@team, @membership), params: { role: "admin" }
    assert_equal "You are not allowed to do that", flash[:alert]
    assert_predicate @membership.reload, :member?
  end

  test "removes the member" do
    sign_in users(:one)
    delete settings_team_member_path(@team, @membership)
    assert_redirected_to settings_team_path(@team)
    assert_not_includes @team.members, users(:two)
  end

  test "cannot remove the owner" do
    sign_in users(:one)
    delete settings_team_member_path(@team, memberships(:acme_owner))
    assert_response :not_found
  end
end
