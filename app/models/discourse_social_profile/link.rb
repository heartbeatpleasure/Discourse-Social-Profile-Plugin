# frozen_string_literal: true

require "securerandom"

module ::DiscourseSocialProfile
  class Link < ActiveRecord::Base
    self.table_name = "discourse_social_profile_links"

    CLICK_TOKEN_BYTES = 24
    CLICK_TOKEN_LENGTH = 32
    CLICK_TOKEN_PATTERN = /\A[A-Za-z0-9_-]{#{CLICK_TOKEN_LENGTH}}\z/

    belongs_to :user
    belongs_to :platform,
               class_name: "::DiscourseSocialProfile::Platform",
               inverse_of: :links

    validates :user_id, presence: true
    validates :platform_id, presence: true
    validates :value, presence: true, length: { maximum: 2048 }
    validates :click_token,
              presence: true,
              uniqueness: true,
              length: { is: CLICK_TOKEN_LENGTH },
              format: { with: CLICK_TOKEN_PATTERN }
    validates :platform_id, uniqueness: { scope: :user_id }
    validate :value_matches_platform

    before_validation :ensure_click_token, on: :create
    before_validation :normalize_value

    private

    def ensure_click_token
      self.click_token ||= SecureRandom.urlsafe_base64(CLICK_TOKEN_BYTES)
    end

    def normalize_value
      self.value = value.to_s.strip
      return if platform.blank? || value.blank?
      @link_builder_result = ::DiscourseSocialProfile::LinkBuilder.call(platform, value)
      self.value = @link_builder_result.canonical_value if @link_builder_result.ok?
    end

    def value_matches_platform
      return if platform.blank? || value.blank?
      result = @link_builder_result || ::DiscourseSocialProfile::LinkBuilder.call(platform, value)
      errors.add(:value, "is invalid (#{result.error_code})") unless result.ok?
    end
  end
end
