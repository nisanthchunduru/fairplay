require "sidekiq"

module Sidekiq
  class Client
    class << self
      def enqueue_at(time, *args)
        enqueue_in(time - Time.now, *args)
      end
    end
  end
end

require "fairplay/enqueuer"

module Fairplay
  class << self
    def enqueue(*args)
      Enqueuer.new(args).enqueue
    end

    def redis
      Redis.new
    end
  end
end
