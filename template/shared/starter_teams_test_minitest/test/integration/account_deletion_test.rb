# frozen_string_literal: true

require "test_helper"

class AccountDeletionTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  test "is refused while the user owns a team other people belong to" do
    sign_in users(:one)

    assert_no_difference "User.count" do
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    end
    assert_redirected_to settings_teams_path
    assert_includes teams(:acme).members, users(:two)
  end

  test "goes through once the other members are gone" do
    sign_in users(:one)
    memberships(:acme_member).destroy!

    assert_difference -> { User.count } => -1, -> { Team.count } => -2 do
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    end
  end
end
