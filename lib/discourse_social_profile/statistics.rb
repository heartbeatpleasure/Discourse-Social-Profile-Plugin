# frozen_string_literal: true

module ::DiscourseSocialProfile
  module Statistics
    CACHE_KEY_PREFIX = "discourse-social-profile:statistics:v5"
    CACHE_TTL = 5.minutes
    INVALID_AUDIT_LIMIT = 5000
    INVALID_AUDIT_BUDGET = 2.seconds
    MIN_CLICK_RETENTION_DAYS = 30
    MAX_CLICK_RETENTION_DAYS = 3650

    module_function

    def summary
      Discourse.cache.fetch(cache_key, expires_in: CACHE_TTL) { calculate }
    rescue Redis::BaseError => e
      Rails.logger.warn("[discourse-social-profile] statistics cache unavailable: #{e.class}")
      calculate
    end

    def clear!
      retention_days = click_retention_days
      Discourse.cache.delete("#{CACHE_KEY_PREFIX}:clicks-0:retention-#{retention_days}")
      Discourse.cache.delete("#{CACHE_KEY_PREFIX}:clicks-1:retention-#{retention_days}")
      true
    rescue Redis::BaseError => e
      Rails.logger.warn("[discourse-social-profile] statistics cache clear failed: #{e.class}")
      false
    end

    def cache_key
      "#{CACHE_KEY_PREFIX}:clicks-#{SiteSetting.discourse_social_profile_track_clicks ? 1 : 0}:retention-#{click_retention_days}"
    end

    def calculate
      total_users = User.human_users.where(staged: false).count
      eligible_user_ids = User.human_users.where(staged: false).select(:id)
      total_links = Link.where(user_id: eligible_user_ids).count
      linked_users = Link.where(user_id: eligible_user_ids).distinct.count(:user_id)
      distribution = link_distribution
      retention_days = click_retention_days

      click_rows = click_statistics(retention_days)
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
              clicks_retention: clicks_by_platform.dig(platform.id, :clicks_retention).to_i,
            }
          end
          .sort_by { |row| [-row[:users], row[:label].to_s.downcase] }

      invalid_audit = audit_invalid_links
      clicks_30d_total = click_rows.sum { |row| row[:clicks_30d].to_i }
      clicks_retention_total = click_rows.sum { |row| row[:clicks_retention].to_i }

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
        invalid_values_scan_timed_out: invalid_audit[:timed_out],
        invalid_values_audit_limit: INVALID_AUDIT_LIMIT,
        new_links_7d: Link.where(user_id: eligible_user_ids).where("created_at >= ?", 7.days.ago).count,
        new_links_30d: Link.where(user_id: eligible_user_ids).where("created_at >= ?", 30.days.ago).count,
        changed_links_7d: Link.where(user_id: eligible_user_ids).where("updated_at >= ?", 7.days.ago).count,
        changed_links_30d: Link.where(user_id: eligible_user_ids).where("updated_at >= ?", 30.days.ago).count,
        distribution: distribution,
        platforms: usage,
        clicks: click_rows.select { |row| row[:clicks_30d].positive? },
        clicks_30d_total: clicks_30d_total,
        clicks_retention_total: clicks_retention_total,
        click_retention_days: retention_days,
        click_retention_matches_30d: retention_days == 30,
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
          COUNT(*) FILTER (WHERE link_count = 5) AS five,
          COUNT(*) FILTER (WHERE link_count >= 6) AS six_plus
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
        five: row["five"].to_i,
        six_plus: row["six_plus"].to_i,
      }
    end

    def audit_invalid_links
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + INVALID_AUDIT_BUDGET.to_f
      rows = Link.includes(:platform).order(:id).limit(INVALID_AUDIT_LIMIT + 1).to_a
      truncated = rows.length > INVALID_AUDIT_LIMIT
      invalid = 0
      audited = 0
      timed_out = false

      rows.first(INVALID_AUDIT_LIMIT).each do |link|
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          timed_out = true
          break
        end

        invalid += 1 unless LinkBuilder.call(link.platform, link.value).ok?
        audited += 1
      end

      { invalid: invalid, audited: audited, truncated: truncated || timed_out, timed_out: timed_out }
    end

    def click_statistics(retention_days = click_retention_days)
      return [] unless SiteSetting.discourse_social_profile_track_clicks

      # Calendar-day statistics: today plus the previous 29 dates is exactly 30
      # days. Retention follows the same convention, so 365 means exactly 365
      # stored/reportable calendar dates including today.
      start_30d = 29.days.ago.to_date
      start_retention = (retention_days - 1).days.ago.to_date
      scope = ClickStat.where("stat_date >= ?", start_retention)
      clicks_retention = scope.group(:platform_id).sum(:click_count)
      clicks_30d = scope.where("stat_date >= ?", start_30d).group(:platform_id).sum(:click_count)
      platform_ids = clicks_retention.keys | clicks_30d.keys
      labels = Platform.where(id: platform_ids).pluck(:id, :label).to_h
      total_30d = clicks_30d.values.sum.to_i
      total_retention = clicks_retention.values.sum.to_i

      platform_ids
        .map do |platform_id|
          count_30d = clicks_30d[platform_id].to_i
          count_retention = clicks_retention[platform_id].to_i
          {
            platform_id: platform_id,
            label: labels[platform_id],
            clicks_30d: count_30d,
            clicks_retention: count_retention,
            click_share_percentage:
              total_30d.positive? ? ((count_30d.to_f / total_30d) * 100).round(1) : 0.0,
            retention_click_share_percentage:
              total_retention.positive? ? ((count_retention.to_f / total_retention) * 100).round(1) : 0.0,
          }
        end
        .sort_by { |row| [-row[:clicks_retention], -row[:clicks_30d], row[:label].to_s.downcase] }
    end

    def click_retention_days
      SiteSetting.discourse_social_profile_click_stats_retention_days.to_i.clamp(
        MIN_CLICK_RETENTION_DAYS,
        MAX_CLICK_RETENTION_DAYS,
      )
    end
  end
end
