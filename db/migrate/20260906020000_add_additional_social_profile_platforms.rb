# frozen_string_literal: true

class AddAdditionalSocialProfilePlatforms < ActiveRecord::Migration[8.0]
  class MigrationPlatform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"
  end

  NEW_KEYS = %w[
    reddit snapchat pinterest kick patreon kofi buymeacoffee beacons medium
    deviantart vimeo flickr chaturbate manyvids loyalfans clips4sale iwantclips
    redgifs xvideos
  ].freeze

  def up
    require File.expand_path("../../lib/discourse_social_profile/default_platforms", __dir__)

    defaults =
      DiscourseSocialProfile::DefaultPlatforms::DATA.index_by { |attributes| attributes[:key] }

    NEW_KEYS.each do |key|
      next if MigrationPlatform.exists?(key: key)

      attributes = defaults.fetch(key)
      MigrationPlatform.create!(attributes)
    end
  end

  # Added platform rows become ordinary admin-managed records. Do not remove
  # them on rollback because admins may have edited them or users may already
  # have stored values that reference them.
  def down
  end
end
