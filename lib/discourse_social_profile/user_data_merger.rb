# frozen_string_literal: true

require "set"

module ::DiscourseSocialProfile
  module UserDataMerger
    MAX_CONFLICT_RETRIES = 3

    module_function

    # Preserve the target account's value when both accounts have the same
    # platform; move source-only rows in place so their opaque click token remains
    # unique without copying a second row. Normal Preferences saves are serialized
    # with the same per-user mutexes. The database retry still protects the rare
    # Redis-unavailable/concurrent-insert case.
    def call(source_user_id, target_user_id)
      source_id = Integer(source_user_id)
      target_id = Integer(target_user_id)
      return true if source_id <= 0 || target_id <= 0 || source_id == target_id

      ids = [source_id, target_id].sort
      begin
        with_user_mutexes(ids) { merge_rows(source_id, target_id) }
      rescue Redis::BaseError => e
        Rails.logger.warn(
          "[discourse-social-profile] merge mutex unavailable; using DB conflict protection: #{e.class}",
        )
        merge_rows(source_id, target_id)
      end

      Statistics.clear!
      true
    end

    def with_user_mutexes(ids, index = 0, &block)
      return yield if index >= ids.length

      DistributedMutex.synchronize("social-profile-preferences-#{ids[index]}") do
        with_user_mutexes(ids, index + 1, &block)
      end
    end
    private_class_method :with_user_mutexes

    def merge_rows(source_id, target_id)
      attempts = 0

      begin
        Link.transaction do
          source_links = Link.where(user_id: source_id).order(:platform_id).lock.to_a
          next if source_links.empty?

          source_platform_ids = source_links.map(&:platform_id)
          target_platform_ids =
            Link
              .where(user_id: target_id, platform_id: source_platform_ids)
              .order(:platform_id)
              .lock
              .pluck(:platform_id)
              .to_set

          conflicting_ids =
            source_links.filter_map { |link| link.id if target_platform_ids.include?(link.platform_id) }
          Link.where(id: conflicting_ids).delete_all if conflicting_ids.any?

          movable_ids = source_links.reject { |link| target_platform_ids.include?(link.platform_id) }.map(&:id)
          if movable_ids.any?
            Link.where(id: movable_ids).update_all(user_id: target_id, updated_at: Time.zone.now)
          end
        end
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < MAX_CONFLICT_RETRIES
        raise
      end
    end
    private_class_method :merge_rows
  end
end
