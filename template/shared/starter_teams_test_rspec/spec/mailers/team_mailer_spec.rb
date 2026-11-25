# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamMailer, type: :mailer do
  fixtures :users, :teams, :memberships

  describe "invitation" do
    let(:invitation) do
      teams(:acme).invitations.create!(email: "new@example.com", role: "member", invited_by: users(:one))
    end
    let(:mail) { described_class.with(invitation: invitation).invitation }

    it "sends to the invited email" do
      expect(mail.to).to eq([ "new@example.com" ])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("You've been invited to join Acme")
    end

    it "links to the sign in page with the invitation" do
      expect(mail.body.encoded).to include("/sign_in?invitation=#{invitation.code}")
    end
  end
end
