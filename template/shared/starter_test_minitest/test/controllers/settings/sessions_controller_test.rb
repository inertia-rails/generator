# frozen_string_literal: true

require "test_helper"

class Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders sessions index" do
    get settings_sessions_path
    assert_response :success
  end
end
