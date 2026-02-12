# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Emails", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/email" do
    it "renders the email settings page" do
      get settings_email_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /settings/email" do
    it "updates email with valid password" do
      patch settings_email_path, params: {
        email: "updated@example.com",
        password_challenge: "Secret1*3*5*"
      }
      expect(response).to redirect_to(settings_email_path)
      expect(users(:one).reload.email).to eq("updated@example.com")
    end

    it "rejects email update with wrong password" do
      patch settings_email_path, params: {
        email: "updated@example.com",
        password_challenge: "wrongpassword"
      }
      expect(response).to redirect_to(settings_email_path)
      expect(users(:one).reload.email).to eq("one@example.com")
    end
  end
end
