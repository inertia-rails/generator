require "application_system_test_case"

class TeamsTest < ApplicationSystemTestCase
  test "switching teams, creating a team and inviting a member" do
    sign_in_as users(:one)
    assert_current_path team_dashboard_path(teams(:one_personal))

    click_on "Test User's Team"
    click_on "Acme"
    assert_current_path team_dashboard_path(teams(:acme))

    click_on "Acme"
    find("[role=menuitem]", text: "New team").click
    fill_in "Team name", with: "Rocket"
    click_on "Create team"
    assert_current_path settings_team_path("rocket")

    click_on "Invite member"
    fill_in "Email address", with: "two@example.com"
    find("#invitation_role").click
    assert_no_selector "[role=option]", text: /owner/i
    find("[role=option]", text: /admin/i).click
    click_on "Send invitation"
    assert_text "Pending invitations"
    assert_text "two@example.com"
  end

  test "accepting an invitation from the dashboard" do
    teams(:one_personal).invitations.create!(email: "two@example.com", role: "member", invited_by: users(:one))

    sign_in_as users(:two)
    assert_text "Test User invited you to join this team."

    click_on "Accept"
    assert_current_path team_dashboard_path(teams(:one_personal))
    assert_no_text "invited you to join this team."
  end

  private

  def sign_in_as(user)
    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Log in"
  end
end
