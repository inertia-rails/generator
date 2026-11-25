# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Account deletion", type: :request do
  fixtures :users, :teams, :memberships

  it "is refused while the user owns a team other people belong to" do
    sign_in users(:one)

    expect {
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    }.not_to change(User, :count)
    expect(response).to redirect_to(settings_teams_path)
    expect(teams(:acme).members).to include(users(:two))
  end

  it "goes through once the other members are gone" do
    sign_in users(:one)
    memberships(:acme_member).destroy!

    expect {
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    }.to change(User, :count).by(-1).and change(Team, :count).by(-2)
  end
end
