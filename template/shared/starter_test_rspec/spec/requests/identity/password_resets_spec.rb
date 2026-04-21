# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Identity::PasswordResets", type: :request do
  fixtures :users

  describe "GET /identity/password_reset/new" do
    it "renders the forgot password page" do
      get new_identity_password_reset_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /identity/password_reset" do
    it "sends password reset email for verified user" do
      expect {
        post identity_password_reset_path, params: { email: users(:one).email }
      }.to have_enqueued_mail(UserMailer, :password_reset)
      expect(response).to redirect_to(sign_in_path)
    end

    it "rejects password reset for unverified user" do
      users(:one).update!(verified: false)
      expect {
        post identity_password_reset_path, params: { email: users(:one).email }
      }.not_to have_enqueued_mail(UserMailer, :password_reset)
      expect(response).to redirect_to(new_identity_password_reset_path)
    end
  end

  describe "GET /identity/password_reset/edit" do
    it "renders the reset page with valid token" do
      sid = users(:one).generate_token_for(:password_reset)
      get edit_identity_password_reset_path(sid: sid)
      expect(response).to have_http_status(:success)
    end

    it "rejects invalid reset token" do
      get edit_identity_password_reset_path(sid: "invalid")
      expect(response).to redirect_to(new_identity_password_reset_path)
    end
  end

  describe "PATCH /identity/password_reset" do
    it "updates password with valid token" do
      sid = users(:one).generate_token_for(:password_reset)
      patch identity_password_reset_path(sid: sid), params: {
        password: "NewPassword1*3*",
        password_confirmation: "NewPassword1*3*"
      }
      expect(response).to redirect_to(sign_in_path)
    end

    it "rejects mismatched password confirmation" do
      sid = users(:one).generate_token_for(:password_reset)
      patch identity_password_reset_path(sid: sid), params: {
        password: "NewPassword1*3*",
        password_confirmation: "different"
      }
      expect(response).to redirect_to(edit_identity_password_reset_path(sid: sid))
    end
  end
end
