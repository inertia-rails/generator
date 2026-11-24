# frozen_string_literal: true

require "test_helper"

class TeamAuthenticationTest < ActionDispatch::IntegrationTest
  fixtures :users, :teams, :memberships

  test "returns to the bookmarked team after sign-in" do
    bookmark = team_dashboard_path(teams(:acme))
    get bookmark
    assert_redirected_to sign_in_path

    post sign_in_path, params: { email: users(:two).email, password: "Secret1*3*5*" }
    assert_redirected_to bookmark
  end

  test "sends a signed-in invitee from the email link to the dashboard" do
    user = users(:two)
    invitation = teams(:one_personal).invitations.create!(email: user.email, role: "member", invited_by: users(:one))
    sign_in user

    get sign_in_path(invitation: invitation.code)
    assert_redirected_to dashboard_path
  end

  test "keeps the invitation on the form after an authentication error" do
    [ sign_in_path, sign_up_path ].each do |path|
      form_url = "http://www.example.com#{path}?invitation=example"
      post path, params: { email: "invalid" }, headers: { "Referer" => form_url }
      assert_redirected_to form_url
    end
  end
end
