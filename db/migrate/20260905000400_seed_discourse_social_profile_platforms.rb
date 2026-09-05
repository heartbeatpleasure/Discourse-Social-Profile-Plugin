# frozen_string_literal: true

class SeedDiscourseSocialProfilePlatforms < ActiveRecord::Migration[8.0]
  class MigrationPlatform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"
  end

  def up
    require File.expand_path("../../lib/discourse_social_profile/default_platforms", __dir__)

    DiscourseSocialProfile::DefaultPlatforms::DATA.each do |attributes|
      next if MigrationPlatform.exists?(key: attributes[:key])
      MigrationPlatform.create!(attributes)
    end
  end

  # Seeded rows become ordinary admin-managed records. Do not delete them in a
  # single-step rollback because they may have been edited or referenced.
  def down
  end
end
