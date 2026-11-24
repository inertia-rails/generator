# frozen_string_literal: true

class SessionsController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]
  before_action :set_session, only: :destroy

  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { <%= use_teams ? "redirect_back_or_to sign_in_path, allow_other_host: false" : "redirect_to sign_in_path" %>, alert: "Too many attempts. Try again later" }

  def new
<% if use_teams && use_alba %>
    @team_invitation = team_invitation
<% elsif use_teams %>
    render inertia: { team_invitation: team_invitation }
<% end %>
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }

      redirect_to <%= use_teams ? "url_from(session.delete(:return_to_after_sign_in)) || dashboard_path" : "dashboard_path" %>, notice: "Signed in successfully"
    else
      <%= use_teams ? "redirect_back_or_to sign_in_path, allow_other_host: false" : "redirect_to sign_in_path" %>, alert: "That email or password is incorrect"
    end
  end

  def destroy
    @session.destroy!
    Current.session = nil
    redirect_to settings_sessions_path, notice: "That session has been logged out", inertia: { clear_history: true }
  end

  private

  def set_session
    @session = Current.user.sessions.find(params[:id])
  end
end
