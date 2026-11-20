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

  test "takes the teams nobody else belongs to with it when deleted" do
    users(:two).destroy!

    assert_equal [ teams(:acme), teams(:one_personal) ], Team.order(:name).to_a
    assert_equal [ users(:one) ], teams(:acme).members.to_a
  end
end
