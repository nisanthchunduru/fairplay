require "active_support/all"
require "fairplay/rate_limit"

module Fairplay
  class RateLimitPolicy
    class << self
      def limit(limit = nil)
        return @limit unless limit
        @limit = limit
      end

      def period(period = nil)
        return @period unless period
        @period = period
      end

      def penalty(penalty = nil)
        return @penalty unless penalty
        @penalty = penalty
      end
    end

    attr_reader :enqueue_args

    def initialize(enqueue_args)
      @enqueue_args = enqueue_args
    end

    def key
      key_method = underscore_name.sub("rate_limit_on_", "")
      worker_class.new.send(key_method, *job_args)
    end

    def increment_rate_limit_count
      rate_limit.increment_count(key)
    end

    def rate_limit_job?
      rate_limit.limit_exceeded?(key)
    end

    def penalty
      self.class.penalty
    end

    private

    def underscore_name
      name.underscore
    end

    def name
      self.class.name.demodulize
    end

    def rate_limit
      return @rate_limit if @rate_limit

      redis_namespace = "fairplay:sidekiq_workers:#{worker_class_name}:rate_limit_policies:#{name}"
      options = {
        limit: self.class.limit + 1,
        period: self.class.period
      }
      @rate_limit = Fairplay::RateLimit.new(redis_namespace, options)
    end

    def worker_class_name
      worker_class.to_s.demodulize
    end

    def worker_class
      enqueue_args.first
    end

    def job_args
      enqueue_args[1..-1]
    end
  end
end
