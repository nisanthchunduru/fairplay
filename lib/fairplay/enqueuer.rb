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
      unless rate_limit_job?
        enqueue_now
        return
      end

      enqueue_at(overshot_rate_limit_policy.enqueue_job_at)
    end

    def worker_has_rate_limit_policies?
      !rate_limit_policies.empty?
    end

    def rate_limit_policies
      return @rate_limit_policies if @rate_limit_policies

      rate_limit_policy_classes = worker.constants.select { |constant| constant.to_s.start_with?("RateLimitOn") }.map { |constant| worker.const_get(constant) }
      @rate_limit_policies = rate_limit_policy_classes.map { |rate_limit_policy_class| rate_limit_policy_class.new(enqueue_args) }
    end

    def worker
      enqueue_args.first
    end

    def enqueue_now
      Sidekiq::Client.enqueue(*enqueue_args)
    end

    def enqueue_at(enqueue_time)
      Sidekiq::Client.enqueue_in(enqueue_time.to_i - Time.now.to_i, *enqueue_args)
    end

    def increment_rate_limit_counts
      rate_limit_policies.each(&:increment_rate_limit_count)
    end

    def rate_limit_job?
      !!overshot_rate_limit_policy
    end

    def overshot_rate_limit_policy
      @overshot_rate_limit_policy ||= rate_limit_policies.find { |policy| policy.rate_limit_job? }
    end
  end
end
