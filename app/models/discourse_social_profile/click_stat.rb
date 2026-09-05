# frozen_string_literal: true

module ::DiscourseSocialProfile
  class ClickStat < ActiveRecord::Base
    self.table_name = "discourse_social_profile_click_stats"

    belongs_to :platform,
               class_name: "::DiscourseSocialProfile::Platform",
               inverse_of: :click_stats

    validates :stat_date, presence: true
    validates :platform_id, uniqueness: { scope: :stat_date }
    validates :click_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def self.increment_for!(platform_id, date: Date.current)
      connection.exec_query(
        sanitize_sql_array(
          [
            <<~SQL,
              INSERT INTO discourse_social_profile_click_stats
                (stat_date, platform_id, click_count, created_at, updated_at)
              VALUES (?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
              ON CONFLICT (stat_date, platform_id)
              DO UPDATE SET click_count = discourse_social_profile_click_stats.click_count + 1,
                            updated_at = CURRENT_TIMESTAMP
            SQL
            date,
            platform_id,
          ],
        ),
      )
    end
  end
end
