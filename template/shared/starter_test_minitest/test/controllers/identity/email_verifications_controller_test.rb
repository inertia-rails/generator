# frozen_string_literal: true

require "test_helper"

class Identity::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "verifies email with valid token" do
    user = users(:one)
    user.update!(verified: false)
    sid = user.generate_token_for(:email_verification)

    get identity_email_verification_path(sid: sid)
    assert_redirected_to root_path

    assert user.reload.verified?
  end

  test "rejects invalid verification token" do
    get identity_email_verification_path(sid: "invalid")
    assert_redirected_to settings_email_path
  end

  test "resends verification email" do
    sign_in users(:one)

    assert_enqueued_emails 1 do
      post identity_email_verification_path
    end
    assert_response :redirect
  end
end
