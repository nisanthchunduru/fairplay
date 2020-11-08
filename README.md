# fairplay
Fairplay is an easy to use rate limited enqueuer for Sidekiq

## Installation

Add the fairplay gem to your app's Gemfile

```ruby
gem 'fairplay'
```

Run

```
bundle install
```

Add a rate limit policy to a Sidekiq worker you wish to rate limit. Here's an example below

```ruby
# In app/workers/process_message.rb
class ProcessMessage
  include Sidekiq::Worker

  class RateLimitOnSenderId < Fairplay::RateLimitPolicy
    limit 15
    period 1.minute
    penalty 30.seconds
    
    def sender_id(job_args)
      message_id = job_args.first
      Message.find(message_id).sender_id
    end
  end
    
  def perform(message_id)
    # ...
  end
end
```

Enqueue the job with Fairplay

```ruby
Fairplay.enqueue(ProcessMessage, message_id)
```

In a typical scenario, Fairplay will enqueue jobs in Sidekiq immediately. However, when a job hits a rate limit, Fairplay will enqueue every subsequent job with the specificed delay (utilizing Sidekiq's [Scheduled Jobs](https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs) feature).

When

- A new rate limit period begins
- ***And*** all rate limits jobs have been processed

Fairplay will a start to enqueue new jobs immediately. This behaviour preserves the order of of jobs.
