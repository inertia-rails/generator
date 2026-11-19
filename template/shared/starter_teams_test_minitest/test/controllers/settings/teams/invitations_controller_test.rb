# frozen_string_literal: true

require "test_helper"

class Settings::Teams::InvitationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  fixtures :users, :teams, :memberships

  setup do
    @team = teams(:acme)
  end

  test "invites someone by email" do
    sign_in users(:one)

    assert_enqueued_email_with TeamMailer, :invitation, params: ->(params) { params[:invitation].email == "new@example.com" } do
      post settings_team_invitations_path(@team), params: { email: "New@Example.com", role: "admin" }
    end

    assert_redirected_to settings_team_path(@team)
    assert_predicate @team.invitations.pending.last, :admin?
  end

  test "rejects someone who is already a member" do
    sign_in users(:one)
    post settings_team_invitations_path(@team), params: { email: "two@example.com", role: "member" }
    assert_equal({ email: [ "is already a member of the team" ] }, session[:inertia_errors])
  end

  test "inviting is not allowed for a member" do
    sign_in users(:two)

    assert_no_difference "Invitation.count" do
      post settings_team_invitations_path(@team), params: { email: "new@example.com", role: "member" }
    end
    assert_equal "You are not allowed to do that", flash[:alert]
  end

  test "cancels the invitation" do
    sign_in users(:one)
    invitation = @team.invitations.create!(email: "new@example.com", role: "member", invited_by: users(:one))

    delete settings_team_invitation_path(@team, invitation)
    assert_redirected_to settings_team_path(@team)
    assert_not Invitation.exists?(invitation.id)
  end
end
