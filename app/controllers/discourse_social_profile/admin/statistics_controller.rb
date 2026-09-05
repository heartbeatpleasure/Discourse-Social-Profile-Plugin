# frozen_string_literal: true

module ::DiscourseSocialProfile
  module Admin
    class StatisticsController < ::Admin::AdminController
      requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME

      def index
        response.headers["Cache-Control"] = "no-store"
        Statistics.clear! if params[:refresh].to_s == "true"
        render_json_dump(Statistics.summary)
      end
    end
  end
end
