# frozen_string_literal: true

module ::Jobs
  class DiscourseSocialProfileCleanupClickStats < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      days = SiteSetting.discourse_social_profile_click_stats_retention_days.to_i.clamp(30, 3650)
      deleted = ::DiscourseSocialProfile::ClickStat.where("stat_date < ?", days.days.ago.to_date).delete_all
      ::DiscourseSocialProfile::Statistics.clear! if deleted.positive?
    end
  end
end
