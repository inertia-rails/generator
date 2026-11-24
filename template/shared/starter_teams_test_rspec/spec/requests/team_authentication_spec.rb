# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team authentication", type: :request do
  fixtures :users, :teams, :memberships

  it "returns to the bookmarked team after sign-in" do
    bookmark = team_dashboard_path(teams(:acme))
    get bookmark
    expect(response).to redirect_to(sign_in_path)

    post sign_in_path, params: { email: users(:two).email, password: "Secret1*3*5*" }
    expect(response).to redirect_to(bookmark)
  end

  it "sends a signed-in invitee from the email link to the dashboard" do
    user = users(:two)
    invitation = teams(:one_personal).invitations.create!(email: user.email, role: "member", invited_by: users(:one))
    sign_in user

    get sign_in_path(invitation: invitation.code)
    expect(response).to redirect_to(dashboard_path)
  end

  it "keeps the invitation on the form after an authentication error" do
    [ sign_in_path, sign_up_path ].each do |path|
      form_url = "http://www.example.com#{path}?invitation=example"
      post path, params: { email: "invalid" }, headers: { "Referer" => form_url }
      expect(response).to redirect_to(form_url)
    end
  end
end
