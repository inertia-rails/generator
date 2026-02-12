# frozen_string_literal: true

require "test_helper"

class Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders email settings page" do
    get settings_email_path
    assert_response :success
  end

  test "updates email with valid password" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_email_path
    assert_equal "updated@example.com", users(:one).reload.email
  end

  test "rejects email update with wrong password" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_email_path
    assert_equal "one@example.com", users(:one).reload.email
  end
end
