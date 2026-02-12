# frozen_string_literal: true

class HomeController < InertiaController
  def index
    render inertia: {
      rails_version: Rails.version,
      ruby_version: RUBY_DESCRIPTION,
      inertia_rails_version: InertiaRails::VERSION,
    }
  end
end
