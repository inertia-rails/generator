# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  fixtures :users, :teams, :memberships

  it "gets a personal team on sign up" do
    user = described_class.create!(name: "New User", email: "new@example.com", password: "Secret1*3*5*")

    expect(user.current_team).to have_attributes(name: "New User's Team", personal: true)
    expect(user.current_team.owner).to eq(user)
  end

  it "takes the teams nobody else belongs to with it when deleted" do
    users(:two).destroy!

    expect(Team.all).to contain_exactly(teams(:one_personal), teams(:acme))
    expect(teams(:acme).members).to contain_exactly(users(:one))
  end
end
