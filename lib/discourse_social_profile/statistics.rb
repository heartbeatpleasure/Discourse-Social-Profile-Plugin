# frozen_string_literal: true

module ::DiscourseSocialProfile
  module Statistics
    CACHE_KEY = "discourse-social-profile:statistics:v3"
    CACHE_TTL = 5.minutes
    INVALID_AUDIT_LIMIT = 5000

    module_function

    def summary
      Discourse.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { calculate }
    end

    def clear!
      Discourse.cache.delete(CACHE_KEY)
    end

    def calculate
      total_users = User.human_users.where(staged: false).count
      eligible_user_ids = User.human_users.where(staged: false).select(:id)
      total_links = Link.where(user_id: eligible_user_ids).count
      linked_users = Link.where(user_id: eligible_user_ids).distinct.count(:user_id)
      distribution = link_distribution

      click_rows = click_statistics
      clicks_by_platform = click_rows.index_by { |row| row[:platform_id] }

      usage =
        Platform
          .ordered
          .left_joins(links: :user)
          .group("discourse_social_profile_platforms.id")
          .select(
            "discourse_social_profile_platforms.*, " \
              "COUNT(discourse_social_profile_links.id) FILTER " \
              "(WHERE users.id > 0 AND NOT users.staged) AS usage_count_value",
          )
          .map do |platform|
            count = platform.usage_count_value.to_i
            {
              id: platform.id,
              key: platform.key,
              label: platform.label,
              enabled: platform.enabled,
              users: count,
              percentage_of_linked_users:
                linked_users.positive? ? ((count.to_f / linked_users) * 100).round(1) : 0.0,
              clicks_30d: clicks_by_platform.dig(platform.id, :clicks_30d).to_i,
            }
          end
          .sort_by { |row| [-row[:users], row[:label].to_s.downcase] }

      invalid_audit = audit_invalid_links
      clicks_30d_total = click_rows.sum { |row| row[:clicks_30d].to_i }

      {
        generated_at: Time.zone.now,
        total_users: total_users,
        users_with_profiles: linked_users,
        adoption_percentage: total_users.positive? ? ((linked_users.to_f / total_users) * 100).round(1) : 0.0,
        total_links: total_links,
        average_links_per_linked_user: linked_users.positive? ? (total_links.to_f / linked_users).round(2) : 0.0,
        average_links_per_all_users: total_users.positive? ? (total_links.to_f / total_users).round(2) : 0.0,
        invalid_values_detected: invalid_audit[:invalid],
        invalid_values_audited: invalid_audit[:audited],
        invalid_values_scan_truncated: invalid_audit[:truncated],
        invalid_values_audit_limit: INVALID_AUDIT_LIMIT,
        new_links_7d: Link.where(user_id: eligible_user_ids).where("created_at >= ?", 7.days.ago).count,
        new_links_30d: Link.where(user_id: eligible_user_ids).where("created_at >= ?", 30.days.ago).count,
        changed_links_7d: Link.where(user_id: eligible_user_ids).where("updated_at >= ?", 7.days.ago).count,
        changed_links_30d: Link.where(user_id: eligible_user_ids).where("updated_at >= ?", 30.days.ago).count,
        distribution: distribution,
        platforms: usage,
        clicks: click_rows,
        clicks_30d_total: clicks_30d_total,
        click_tracking_enabled: SiteSetting.discourse_social_profile_track_clicks,
      }
    end

    def link_distribution
      table = Link.quoted_table_name
      row = Link.connection.select_one(<<~SQL)
        SELECT
          COUNT(*) FILTER (WHERE link_count = 1) AS one,
          COUNT(*) FILTER (WHERE link_count = 2) AS two,
          COUNT(*) FILTER (WHERE link_count = 3) AS three,
          COUNT(*) FILTER (WHERE link_count = 4) AS four,
          COUNT(*) FILTER (WHERE link_count >= 5) AS five_plus
        FROM (
          SELECT links.user_id, COUNT(*) AS link_count
          FROM #{table} links
          INNER JOIN users ON users.id = links.user_id
          WHERE users.id > 0 AND NOT users.staged
          GROUP BY links.user_id
        ) AS link_counts
      SQL
      {
        one: row["one"].to_i,
        two: row["two"].to_i,
        three: row["three"].to_i,
        four: row["four"].to_i,
        five_plus: row["five_plus"].to_i,
      }
    end

    def audit_invalid_links
      rows = Link.includes(:platform).order(:id).limit(INVALID_AUDIT_LIMIT + 1).to_a
      truncated = rows.length > INVALID_AUDIT_LIMIT
      audited_rows = rows.first(INVALID_AUDIT_LIMIT)
      invalid = audited_rows.count { |link| !LinkBuilder.call(link.platform, link.value).ok? }
      { invalid: invalid, audited: audited_rows.length, truncated: truncated }
    end

    def click_statistics
      return [] unless SiteSetting.discourse_social_profile_track_clicks

      clicks = ClickStat.where("stat_date >= ?", 30.days.ago.to_date).group(:platform_id).sum(:click_count)
      labels = Platform.where(id: clicks.keys).pluck(:id, :label).to_h
      total = clicks.values.sum.to_i
      clicks
        .map do |platform_id, count|
          {
            platform_id: platform_id,
            label: labels[platform_id],
            clicks_30d: count,
            click_share_percentage: total.positive? ? ((count.to_f / total) * 100).round(1) : 0.0,
          }
        end
        .sort_by { |row| -row[:clicks_30d] }
    end
  end
end
