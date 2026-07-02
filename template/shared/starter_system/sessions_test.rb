require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in shows the dashboard" do
    visit sign_in_path

    fill_in "Email address", with: users(:one).email
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Log in"

    assert_current_path dashboard_path
    assert_text "Dashboard"
  end
end
