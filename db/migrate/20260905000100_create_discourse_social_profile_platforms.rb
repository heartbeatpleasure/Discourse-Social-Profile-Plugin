# frozen_string_literal: true

class CreateDiscourseSocialProfilePlatforms < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_social_profile_platforms do |t|
      t.string :key, limit: 64, null: false
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.string :label, limit: 100, null: false
      t.text :user_instructions
      t.string :placeholder, limit: 255
      t.string :input_type, limit: 32, null: false
      t.text :base_url
      t.text :allowed_hosts
      t.text :path_regex
      t.string :icon_name, limit: 100
      t.string :builtin_icon, limit: 100
      t.bigint :icon_image_upload_id
      t.text :icon_image_url
      t.bigint :icon_mask_upload_id
      t.text :icon_mask_url
      t.string :badge_background, limit: 128
      t.string :badge_background_dark, limit: 128
      t.string :badge_radius, limit: 64
      t.string :color, limit: 128
      t.string :color_dark, limit: 128
      t.string :legacy_user_field_name, limit: 255
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end

    add_index :discourse_social_profile_platforms, :key, unique: true
    add_index :discourse_social_profile_platforms, %i[enabled position]
    add_index :discourse_social_profile_platforms, :icon_image_upload_id
    add_index :discourse_social_profile_platforms, :icon_mask_upload_id
    add_foreign_key :discourse_social_profile_platforms, :uploads, column: :icon_image_upload_id, on_delete: :nullify
    add_foreign_key :discourse_social_profile_platforms, :uploads, column: :icon_mask_upload_id, on_delete: :nullify
  end
end
