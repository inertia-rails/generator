# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  fixtures :users

  describe "GET /sign_in" do
    it "renders the sign in page" do
      get sign_in_path
      expect(response).to have_http_status(:success)
    end

    it "redirects authenticated users" do
      sign_in users(:one)
      get sign_in_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /sign_in" do
    context "with valid credentials" do
      it "signs in and sets a session cookie" do
        post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
        expect(response).to redirect_to(dashboard_path)
        expect(cookies[:session_token]).to be_present

        get settings_profile_path
        expect(response).to have_http_status(:success)
      end
    end

    context "with invalid credentials" do
      it "redirects back with an alert" do
        post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq("That email or password is incorrect")

        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /sessions/:id" do
    it "returns to the dashboard on the next sign-in after logging out" do
      user = users(:one)
      sign_in user
      session_record = user.sessions.last
      delete session_path(session_record)
      expect(response).to redirect_to(sign_in_path)
      expect(Session.exists?(session_record.id)).to be(false)

      follow_redirect!
      post sign_in_path, params: { email: user.email, password: "Secret1*3*5*" }
      expect(response).to redirect_to(dashboard_path)
    end

    it "stays in session settings when revoking another session" do
      user = users(:one)
      other_session = user.sessions.create!
      sign_in user

      delete session_path(other_session)
      expect(response).to redirect_to(settings_sessions_path)
      expect(Session.exists?(other_session.id)).to be(false)
      follow_redirect!
      expect(response).to have_http_status(:success)
    end
  end
end
