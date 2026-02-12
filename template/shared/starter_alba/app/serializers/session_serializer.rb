# frozen_string_literal: true

class SessionSerializer < ApplicationSerializer
  attributes :id, :user_agent, :ip_address, :created_at
end
