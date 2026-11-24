# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams", type: :system do
  fixtures :users, :teams, :memberships

  def sign_in_as(user)
    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Log in"
  end

  it "switches teams, creates a team and invites a member" do
    sign_in_as users(:one)
    expect(page).to have_current_path(team_dashboard_path(teams(:one_personal)))

    click_on "Test User's Team"
    click_on "Acme"
    expect(page).to have_current_path(team_dashboard_path(teams(:acme)))

    click_on "Acme"
    find("[role=menuitem]", text: "New team").click
    fill_in "Team name", with: "Rocket"
    click_on "Create team"
    expect(page).to have_current_path(settings_team_path("rocket"))

    click_on "Invite member"
    fill_in "Email address", with: "two@example.com"
    find("#invitation_role").click
    expect(page).to have_no_selector("[role=option]", text: /owner/i)
    find("[role=option]", text: /admin/i).click
    click_on "Send invitation"
    expect(page).to have_text("Pending invitations")
    expect(page).to have_text("two@example.com")
  end

  it "accepts an invitation from the dashboard" do
    teams(:one_personal).invitations.create!(email: "two@example.com", role: "member", invited_by: users(:one))

    sign_in_as users(:two)
    expect(page).to have_text("Test User invited you to join this team.")

    click_on "Accept"
    expect(page).to have_current_path(team_dashboard_path(teams(:one_personal)))
    expect(page).to have_no_text("invited you to join this team.")
  end
end
