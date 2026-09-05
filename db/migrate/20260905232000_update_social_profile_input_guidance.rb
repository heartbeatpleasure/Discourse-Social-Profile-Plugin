# frozen_string_literal: true

class UpdateSocialProfileInputGuidance < ActiveRecord::Migration[8.0]
  class MigrationPlatform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"
  end

  OLD_HANDLE_SUFFIX =
    " without @. A full matching HTTPS profile URL is also accepted."
  NEW_HANDLE_SUFFIX =
    " without @, or paste a full HTTPS URL for this platform."
  OLD_NUMERIC_SUFFIX =
    " user ID. A full matching HTTPS profile URL is also accepted."
  NEW_NUMERIC_SUFFIX =
    " user ID, or paste a full HTTPS URL for this platform."

  def up
    rewrite_guidance(
      input_type: "handle",
      old_suffix: OLD_HANDLE_SUFFIX,
      new_suffix: NEW_HANDLE_SUFFIX,
      old_placeholder: "username",
      new_placeholder: "username or https://...",
    )
    rewrite_guidance(
      input_type: "numeric_id",
      old_suffix: OLD_NUMERIC_SUFFIX,
      new_suffix: NEW_NUMERIC_SUFFIX,
      old_placeholder: "123456789",
      new_placeholder: "123456789 or https://...",
    )
  end

  def down
    rewrite_guidance(
      input_type: "handle",
      old_suffix: NEW_HANDLE_SUFFIX,
      new_suffix: OLD_HANDLE_SUFFIX,
      old_placeholder: "username or https://...",
      new_placeholder: "username",
    )
    rewrite_guidance(
      input_type: "numeric_id",
      old_suffix: NEW_NUMERIC_SUFFIX,
      new_suffix: OLD_NUMERIC_SUFFIX,
      old_placeholder: "123456789 or https://...",
      new_placeholder: "123456789",
    )
  end

  private

  def rewrite_guidance(input_type:, old_suffix:, new_suffix:, old_placeholder:, new_placeholder:)
    MigrationPlatform.where(builtin: true, input_type: input_type).find_each do |platform|
      updates = {}
      instructions = platform.user_instructions.to_s
      if instructions.end_with?(old_suffix)
        updates[:user_instructions] = instructions.delete_suffix(old_suffix) + new_suffix
      end
      if platform.placeholder == old_placeholder
        updates[:placeholder] = new_placeholder
      end
      platform.update_columns(updates) if updates.present?
    end
  end
end
