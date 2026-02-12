# frozen_string_literal: true

require "test_helper"

class Settings::PasswordsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders password settings page" do
    get settings_password_path
    assert_response :success
  end

  test "updates password with valid current password" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_password_path
  end

  test "rejects password update with wrong current password" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_password_path
  end
end
