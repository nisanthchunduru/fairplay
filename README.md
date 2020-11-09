# fairplay
Fairplay is a rate limiter for [Sidekiq](https://github.com/mperham/sidekiq)

## Installation

Add the fairplay gem to your app's Gemfile

```ruby
gem 'fairplay'
```

and install it

```
bundle install
```

## Usage

Add a rate limit policy to the Sidekiq worker you'd like to rate limit. Here's an example below

```ruby
# In app/workers/process_message.rb
class ProcessMessage
  include Sidekiq::Worker

  class RateLimitOnSenderEmail < Fairplay::RateLimitPolicy
    limit 15
    period 1.minute
    penalty 30.seconds
  end

  def sender_email(job_args)
    message_id = job_args.first
    Message.find(message_id).sender_email
  end

  def perform(message_id)
    # ...
  end
end
```

Start enqueuing the job with `Fairplay.enqueue`

```ruby
Fairplay.enqueue(ProcessMessage, message_id)
```

In a normal scenario, `Fairplay.enqueue` enqueues a job in Sidekiq immediately. However, when a job hits a rate limit, `Fairplay.enqueue` will place a time delay (known as penalty) between every subsequent job (utilizing Sidekiq's [Scheduled Jobs](https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs) feature).

When

- A new rate limit period begins
- ***And*** all rate limited jobs have been processed

`Fairplay.enqueue` will resume its normal behaviour and start to enqueue new jobs immediately. This behaviour preserves the order of of jobs.
