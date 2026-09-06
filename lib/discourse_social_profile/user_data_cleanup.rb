# frozen_string_literal: true

module ::DiscourseSocialProfile
  module UserDataCleanup
    module_function

    def call(user_id)
      id = Integer(user_id)
      return if id <= 0

      begin
        DistributedMutex.synchronize("social-profile-preferences-#{id}") { delete_links(id) }
      rescue Redis::BaseError => e
        # Privacy deletion must not depend on Redis availability. The mutex is a
        # race-reduction mechanism, not an authorization boundary; if Redis is
        # unavailable, fall back to the idempotent database delete and let normal
        # DB errors propagate to the retry path.
        Rails.logger.warn(
          "[discourse-social-profile] cleanup mutex unavailable; deleting without lock: #{e.class}",
        )
        delete_links(id)
      end

      Statistics.clear!
      true
    end

    def delete_links(user_id)
      Link.where(user_id: user_id).delete_all
    end
    private_class_method :delete_links
  end
end
