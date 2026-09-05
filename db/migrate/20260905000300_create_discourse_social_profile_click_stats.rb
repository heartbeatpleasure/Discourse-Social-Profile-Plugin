# frozen_string_literal: true

class CreateDiscourseSocialProfileClickStats < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_social_profile_click_stats do |t|
      t.date :stat_date, null: false
      t.bigint :platform_id, null: false
      t.bigint :click_count, null: false, default: 0
      t.timestamps
    end

    add_index :discourse_social_profile_click_stats, %i[stat_date platform_id], unique: true, name: "idx_social_profile_clicks_date_platform"
    add_index :discourse_social_profile_click_stats, :platform_id
    add_foreign_key :discourse_social_profile_click_stats, :discourse_social_profile_platforms, column: :platform_id, on_delete: :cascade
  end
end
