# frozen_string_literal: true

class PotentialFriendshipTracker
  EXPIRE_AFTER = 90.days.seconds
  MAX_ITEMS    = 80

  WEIGHTS = {
    reply: 1,
    favourite: 10,
    reblog: 20,
  }.freeze

  class << self
    include Redisable

    def record(account_id, target_account_id, action)
      return if account_id == target_account_id

      key    = "interactions:#{account_id}"
      weight = WEIGHTS[action]

      redis.zincrby(key, weight, target_account_id)
      redis.zremrangebyrank(key, 0, -MAX_ITEMS)
      redis.expire(key, EXPIRE_AFTER)
    end

    def remove(account_id, target_account_id)
      redis.zrem("interactions:#{account_id}", target_account_id)
    end

    def get(account_id, locale, limit: 20, offset: 0)
      account_ids = redis.zrevrange("interactions:#{account_id}", offset, limit)

      [].tap do |accounts|
        accounts.concat(Account.searchable.where(id: account_ids)) unless account_ids.empty?
        accounts.concat(follow_recommendation_generator.get(locale, limit - accounts.size)) if accounts.size < limit && offset.zero?
      end
    end

    private

    def follow_recommendation_generator
      FollowRecommendationGenerator.new
    end
  end
end
