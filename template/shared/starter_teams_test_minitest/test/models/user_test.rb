# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :users, :teams, :memberships

  test "gets a personal team on sign up" do
    user = User.create!(name: "New User", email: "new@example.com", password: "Secret1*3*5*")

    assert_equal "New User's Team", user.current_team.name
    assert_predicate user.current_team, :personal?
    assert_equal user, user.current_team.owner
  end

  test "fits a long name into the personal team name" do
    user = User.create!(name: "A" * 249, email: "new@example.com", password: "Secret1*3*5*")

    assert_equal "A" * 248 + "'s Team", user.current_team.name
    assert_equal user, user.current_team.owner
  end

  test "rolls back sign up when the personal team is invalid" do
    user = User.new(name: "New User", email: "new@example.com", password: "Secret1*3*5*")

    stub_const(Team::ReservedNames, :ALL, Set["new-user-s-team"]) do
      assert_no_difference [ "User.count", "Team.count", "Membership.count" ] do
        assert_not user.save
      end
    end
    assert user.errors[:base].present?
  end

  test "takes the teams nobody else belongs to with it when deleted" do
    users(:two).destroy!

    assert_equal [ teams(:acme), teams(:one_personal) ], Team.order(:name).to_a
    assert_equal [ users(:one) ], teams(:acme).members.to_a
  end
end
