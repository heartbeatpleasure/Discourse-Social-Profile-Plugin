# frozen_string_literal: true

module ::Jobs
  class DiscourseSocialProfileCleanupUserData < ::Jobs::Base
    sidekiq_options retry: 5

    def execute(args)
      user_id = args[:user_id].to_i
      return if user_id <= 0

      ::DiscourseSocialProfile::UserDataCleanup.call(user_id)
    end
  end
end
