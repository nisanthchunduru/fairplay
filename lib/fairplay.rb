require "sidekiq"
require "fairplay/enqueuer"

module Fairplay
  class << self
    def enqueue(*args)
      Enqueuer.new(args).enqueue
    end
  end
end
