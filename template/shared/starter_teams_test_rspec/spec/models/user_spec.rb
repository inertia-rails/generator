# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  fixtures :users, :teams, :memberships

  it "gets a personal team on sign up" do
    user = described_class.create!(name: "New User", email: "new@example.com", password: "Secret1*3*5*")

    expect(user.current_team).to have_attributes(name: "New User's Team", personal: true)
    expect(user.current_team.owner).to eq(user)
  end

  it "fits a long name into the personal team name" do
    user = described_class.create!(name: "A" * 249, email: "new@example.com", password: "Secret1*3*5*")

    expect(user.current_team.name).to eq("A" * 248 + "'s Team")
    expect(user.current_team.owner).to eq(user)
  end

  it "rolls back sign up when the personal team is invalid" do
    user = described_class.new(name: "New User", email: "new@example.com", password: "Secret1*3*5*")

    def user.create_team(**attributes)
      super(**attributes, name: "")
    end

    expect { expect(user.save).to be(false) }.not_to change { [ User.count, Team.count, Membership.count ] }
    expect(user.errors[:base]).to be_present
  end

  it "preserves the owner and their teams while another member belongs to one" do
    expect { users(:one).destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)

    expect(User.exists?(users(:one).id)).to be(true)
    expect(teams(:one_personal).reload.owner).to eq(users(:one))
    expect(teams(:acme).members).to contain_exactly(users(:one), users(:two))
  end

  it "takes the teams nobody else belongs to with it when deleted" do
    users(:two).destroy!

    expect(Team.all).to contain_exactly(teams(:one_personal), teams(:acme))
    expect(teams(:acme).members).to contain_exactly(users(:one))
  end
end
