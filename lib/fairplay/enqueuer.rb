require "fairplay/rate_limit_policy"

module Fairplay
  class Enqueuer
    attr_reader :enqueue_args

    def initialize(enqueue_args)
      @enqueue_args = enqueue_args
    end

    def enqueue
      unless worker_has_rate_limit_policies?
        enqueue_now
        return
      end

      increment_rate_limit_counts

      last_rate_limited_job_enqueue_time = last_rate_limited_job_enqueue_time()
      if !overshot_rate_limit_policy && !last_rate_limited_job_enqueue_time
        enqueue_now
        return
      end

      enqueue_time = if last_rate_limited_job_enqueue_time && overshot_rate_limit_policy
        last_rate_limited_job_enqueue_time + overshot_rate_limit_policy.penalty
      elsif last_rate_limited_job_enqueue_time
        last_rate_limited_job_enqueue_time
      elsif overshot_rate_limit_policy
        Time.now + overshot_rate_limit_policy.penalty
      end

      enqueue_at(enqueue_time)
      update_last_rate_limited_job_enqueue_time(enqueue_time)
    end

    def worker_has_rate_limit_policies?
      !rate_limit_policies.empty?
    end

    def rate_limit_policies
      return @rate_limit_policies if @rate_limit_policies

      rate_limit_policy_classes = worker_class.constants.select { |constant| constant.to_s.start_with?("RateLimitOn") }.map { |constant| worker_class.const_get(constant) }
      @rate_limit_policies = rate_limit_policy_classes.map { |rate_limit_policy_class| rate_limit_policy_class.new(enqueue_args) }
    end

    def enqueue_now
      Sidekiq::Client.enqueue(*enqueue_args)
    end

    def enqueue_at(enqueue_time)
      Sidekiq::Client.enqueue_at(enqueue_time, *enqueue_args)
    end

    def increment_rate_limit_counts
      rate_limit_policies.each(&:increment_rate_limit_count)
    end

    def overshot_rate_limit_policy
      @overshot_rate_limit_policy ||= rate_limit_policies.find { |policy| policy.rate_limit_job? }
    end

    def last_rate_limited_job_enqueue_time
      redis_key = last_rate_limited_job_enqueue_time_redis_key
      timestamp_in_seconds = redis.get(redis_key).to_i
      timestamp_in_seconds.zero? ? nil : Time.at(timestamp_in_seconds)
    end

    def update_last_rate_limited_job_enqueue_time(new_timestamp)
      redis_key = last_rate_limited_job_enqueue_time_redis_key
      timestamp_in_seconds = new_timestamp.to_i
      redis.multi do
        redis.set(redis_key, timestamp_in_seconds)
        redis.expireat(redis_key, timestamp_in_seconds)
      end
    end

    def last_rate_limited_job_enqueue_time_redis_key
      "fairplay:sidekiq_workers:#{worker_class_name}:last_rate_limited_job_enqueued_time"
    end

    def underscoreized_worker_class_name
      worker_class_name
    end

    def job_args
      enqueue_args[1..-1]
    end

    def worker_class_name
      worker_class.to_s.demodulize
    end

    def worker_class
      enqueue_args.first
    end

    def redis
      @redis ||= Fairplay.redis
    end
  end
end
