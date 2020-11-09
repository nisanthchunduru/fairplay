require "ratelimit"

module Fairplay
  # A wrapper over the ratelimit gem
  class RateLimit
    attr_reader :redis_namespace

    def initialize(redis_namespace, options)
      @redis_namespace = redis_namespace
      @options = options
    end

    def increment_count(identifier)
      ratelimit.add(identifier, 1)
    end

    def within_limit?(identifier)
      ratelimit.within_bounds?(identifier, threshold: limit, interval: period)
    end

    def limit_exceeded?(identifier)
      !within_limit?(identifier)
    end

    private

    def ratelimit
      return @ratelimit if @ratelimit

      bucket_span = 2 * period # Time span to track in seconds
      bucket_interval = 1.minute # How many seconds each bucket represents

      # TODO: Add an explanatory comment and a separate test case
      if bucket_span < 3.minutes
        bucket_span = 3.minutes
      end

      options = {
        bucket_span: bucket_span,
        bucket_interval: bucket_interval,
        redis: Fairplay.redis
      }

      @ratelimit = Ratelimit.new(@redis_namespace, options)
    end

    def period
      @options[:period]
    end

    def limit
      @options[:limit]
    end
  end
end
