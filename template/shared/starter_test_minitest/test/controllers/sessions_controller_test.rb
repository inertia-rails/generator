# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "renders sign in page" do
    get sign_in_path
    assert_response :success
  end

  test "redirects authenticated users away from sign in" do
    sign_in users(:one)
    get sign_in_path
    assert_redirected_to root_path
  end

  test "signs in with valid credentials" do
    post sign_in_path, params: {email: users(:one).email, password: "Secret1*3*5*"}
    assert_redirected_to dashboard_path
    assert cookies[:session_token].present?
  end

  test "rejects invalid credentials" do
    post sign_in_path, params: {email: users(:one).email, password: "wrongpassword"}
    assert_redirected_to sign_in_path
  end

  test "destroys a session" do
    sign_in users(:one)
    session_record = users(:one).sessions.last
    delete session_path(session_record)
    assert_redirected_to settings_sessions_path
  end
end
