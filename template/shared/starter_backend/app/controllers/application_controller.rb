# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate
<% if use_teams %>

  authorize :user, through: -> { Current.user }

  rescue_from ActionPolicy::Unauthorized do
    redirect_back_or_to root_path, alert: "You are not allowed to do that"
  end
<% end %>

  private

  def authenticate
<% if use_teams %>
    return if perform_authentication

    session[:return_to_after_sign_in] = request.fullpath if request.get?
    redirect_to sign_in_path
<% else %>
    redirect_to sign_in_path unless perform_authentication
<% end %>
  end

  def require_no_authentication
    return unless perform_authentication
<% if use_teams %>
    return redirect_to dashboard_path if params[:invitation].present?
<% end %>

    flash[:notice] = "You are already signed in"
    redirect_to root_path
  end

  def perform_authentication
    Current.session ||= Session.find_by_id(cookies.signed[:session_token])
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end
<% if use_teams %>

  # The team invitation a sign in or sign up page was opened with (?invitation=code)
  def team_invitation
    invitation = Invitation.pending.includes(:team).find_by(code: params[:invitation])

    { code: invitation.code, team_name: invitation.team.name } if invitation
  end
<% end %>
end
