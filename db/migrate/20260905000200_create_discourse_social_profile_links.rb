# frozen_string_literal: true

class CreateDiscourseSocialProfileLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_social_profile_links do |t|
      t.integer :user_id, null: false
      t.bigint :platform_id, null: false
      t.text :value, null: false
      t.string :click_token, limit: 64, null: false
      t.timestamps
    end

    add_index :discourse_social_profile_links, :user_id
    add_index :discourse_social_profile_links, :platform_id
    add_index :discourse_social_profile_links, :click_token, unique: true
    add_index :discourse_social_profile_links, %i[user_id platform_id], unique: true, name: "idx_social_profile_links_user_platform"
    add_foreign_key :discourse_social_profile_links, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :discourse_social_profile_links, :discourse_social_profile_platforms, column: :platform_id, on_delete: :restrict
  end
end
