# frozen_string_literal: true

require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  setup do
    @invitation = teams(:one_personal).invitations.create!(email: "two@example.com", role: "admin", invited_by: users(:one))
    sign_in users(:two)
  end

  test "accepting adds the user to the team" do
    post accept_invitation_path(@invitation)
    assert_redirected_to team_dashboard_path(teams(:one_personal))
    assert_predicate teams(:one_personal).memberships.find_by!(user: users(:two)), :admin?
    assert_equal teams(:one_personal), users(:two).reload.current_team
  end

  test "is not found once the invitation has expired" do
    @invitation.update!(expires_at: 1.minute.ago)
    post accept_invitation_path(@invitation)
    assert_response :not_found
  end

  test "is not found when the invitation was sent to someone else" do
    @invitation.update!(email: "someone@example.com")
    post accept_invitation_path(@invitation)
    assert_response :not_found
  end

  test "is not found until the user has verified their email" do
    users(:two).update!(verified: false)
    post accept_invitation_path(@invitation)
    assert_response :not_found
  end

  test "declining deletes the invitation" do
    delete invitation_path(@invitation)
    assert_redirected_to dashboard_path
    assert_not Invitation.exists?(@invitation.id)
  end
end
