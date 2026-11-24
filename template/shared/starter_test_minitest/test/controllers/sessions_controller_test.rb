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
    post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
    assert_redirected_to dashboard_path
    assert cookies[:session_token].present?
  end

  test "rejects invalid credentials" do
    post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
    assert_redirected_to sign_in_path
  end

  test "returns to the dashboard on the next sign-in after logging out" do
    user = users(:one)
    sign_in user
    session_record = user.sessions.last
    delete session_path(session_record)
    assert_redirected_to sign_in_path
    assert_not Session.exists?(session_record.id)

    follow_redirect!
    post sign_in_path, params: { email: user.email, password: "Secret1*3*5*" }
    assert_redirected_to dashboard_path
  end

  test "stays in session settings when revoking another session" do
    user = users(:one)
    other_session = user.sessions.create!
    sign_in user

    delete session_path(other_session)
    assert_redirected_to settings_sessions_path
    assert_not Session.exists?(other_session.id)
    follow_redirect!
    assert_response :success
  end
end
