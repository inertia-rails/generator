# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Identity::EmailVerifications", type: :request do
  fixtures :users

  describe "GET /identity/email_verification" do
    it "verifies email with valid token" do
      user = users(:one)
      user.update!(verified: false)
      sid = user.generate_token_for(:email_verification)

      get identity_email_verification_path(sid: sid)
      expect(response).to redirect_to(root_path)
      expect(user.reload).to be_verified
    end

    it "rejects invalid verification token" do
      get identity_email_verification_path(sid: "invalid")
      expect(response).to redirect_to(settings_email_path)
    end
  end

  describe "POST /identity/email_verification" do
    it "resends verification email" do
      sign_in users(:one)

      expect {
        post identity_email_verification_path
      }.to have_enqueued_mail(UserMailer, :email_verification)
      expect(response).to be_redirect
    end
  end
end
