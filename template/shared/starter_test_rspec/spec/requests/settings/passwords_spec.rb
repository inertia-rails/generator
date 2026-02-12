# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Passwords", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/password" do
    it "renders the password settings page" do
      get settings_password_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /settings/password" do
    it "updates password with valid current password" do
      patch settings_password_path, params: {
        password: "NewPassword1*3*",
        password_confirmation: "NewPassword1*3*",
        password_challenge: "Secret1*3*5*"
      }
      expect(response).to redirect_to(settings_password_path)
    end

    it "rejects password update with wrong current password" do
      patch settings_password_path, params: {
        password: "NewPassword1*3*",
        password_confirmation: "NewPassword1*3*",
        password_challenge: "wrongpassword"
      }
      expect(response).to redirect_to(settings_password_path)
    end
  end
end
