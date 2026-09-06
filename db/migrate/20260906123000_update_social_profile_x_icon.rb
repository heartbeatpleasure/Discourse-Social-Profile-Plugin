# frozen_string_literal: true

class UpdateSocialProfileXIcon < ActiveRecord::Migration[8.0]
  class MigrationPlatform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"
  end

  def up
    MigrationPlatform
      .where(key: "x", icon_name: "fab-twitter", builtin_icon: nil)
      .update_all(icon_name: "fab-x-twitter", updated_at: Time.current)
  end

  # Once installed, platform rows are admin-managed configuration. Do not
  # overwrite a later administrator choice during rollback.
  def down
  end
end
