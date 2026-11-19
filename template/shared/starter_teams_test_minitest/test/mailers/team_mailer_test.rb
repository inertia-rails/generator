# frozen_string_literal: true

require "test_helper"

class TeamMailerTest < ActionMailer::TestCase
  fixtures :users, :teams, :memberships

  test "invitation" do
    invitation = teams(:acme).invitations.create!(email: "new@example.com", role: "member", invited_by: users(:one))
    mail = TeamMailer.with(invitation: invitation).invitation

    assert_equal "You've been invited to join Acme", mail.subject
    assert_equal [ "new@example.com" ], mail.to
    assert_includes mail.body.encoded, "/sign_in?invitation=#{invitation.code}"
  end
end
