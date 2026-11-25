# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invitation
    @invitation = params[:invitation]

    mail to: @invitation.email, subject: "You've been invited to join #{@invitation.team.name}"
  end
end
