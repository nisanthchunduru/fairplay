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

    def initialize(enqueue_args)
      @enqueue_args = enqueue_args
    end

    def increment_rate_limit_count
      entity = public_send(name.sub("rate_limit_on_", ""), job_args)
      rate_limit.increment_count(entity)
    end

    def rate_limit_job?
      limit_exceeded?
    end

    def enqueue_job_at
      Time.now + self.class.penalty
    end

    private

    def limit_exceeded?
      entity = public_send(name.sub("rate_limit_on_", ""), job_args)
      rate_limit.limit_exceeded?(entity)
    end

    def rate_limit
      return @rate_limit if @rate_limit

      redis_namespace = "fairplay/#{lowercase_worker_class_name}/#{name}/last_rate_limited_job_enqueue_time"
      options = {
        limit: self.class.limit + 1,
        period: self.class.period
      }
      @rate_limit = Fairplay::RateLimit.new(redis_namespace, options)
    end

    def lowercase_worker_class_name
      worker_class.to_s.demodulize.underscore
    end

    def name
      self.class.to_s.demodulize.underscore
    end

    def worker_class
      @enqueue_args.first
    end

    def job_args
      @enqueue_args[1..-1]
    end
  end
end
