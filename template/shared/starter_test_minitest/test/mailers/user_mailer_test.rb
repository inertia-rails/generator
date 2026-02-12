# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  fixtures :users

  test "email_verification" do
    mail = UserMailer.with(user: users(:one)).email_verification
    assert_equal "Verify your email", mail.subject
    assert_equal ["one@example.com"], mail.to
  end

  test "password_reset" do
    mail = UserMailer.with(user: users(:one)).password_reset
    assert_equal "Reset your password", mail.subject
    assert_equal ["one@example.com"], mail.to
  end
end
