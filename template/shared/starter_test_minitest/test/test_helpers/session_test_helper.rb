# frozen_string_literal: true

module SessionTestHelper
  def self.signed_cookie(name, value)
    cookie_jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    cookie_jar.signed[name] = value
    cookie_jar[name]
  end

  def sign_in(user)
    session = user.sessions.create!
    cookies[:session_token] = SessionTestHelper.signed_cookie(:session_token, session.id)
  end

  def sign_out
    cookies[:session_token] = ""
  end
end
