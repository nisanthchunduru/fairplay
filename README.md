# fairplay
Fairplay is a rate limiter for [Sidekiq](https://github.com/mperham/sidekiq)

## Installation

Add the fairplay gem to your app's Gemfile

```ruby
gem 'fairplay', :git => "git@github.com:nisanth074/fairplay.git"
```

and install it

```
bundle install
```

## Usage

Add a rate limit policy to the Sidekiq worker you'd like to rate limit like in the example below

```ruby
# In app/workers/process_message.rb
class ProcessMessage
  include Sidekiq::Worker

  class RateLimitOnSenderEmail < Fairplay::RateLimitPolicy
    limit 15
    period 1.minute
    penalty 30.seconds
  end

  def sender_email(message_id)
    Message.find(message_id).sender_email
  end

  def perform(message_id)
    # ...
  end
end
```

Now, start enqueuing jobs with `Fairplay.enqueue`

```ruby
Fairplay.enqueue(ProcessMessage, message_id)
```

## Rate limiting behaviour

In a normal scenario, `Fairplay.enqueue` enqueues a job for immediate execution. However, when a job hits a rate limit, `Fairplay.enqueue` will place a time delay (known as penalty) between every subsequent job (utilizing Sidekiq's [Scheduled Jobs](https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs) feature).

`Fairplay.queue` stops rate limiting once

1. A new rate limit period begins
2. ***And*** all pending rate limited jobs have been processed

The behaviour above ensures that jobs are processed in the order in which they arrive.

## FAQ

1. Has this library seen production use?

Yes. A slightly different version of this gem has been in use in production at supportbee.com for many years. It has enqueued upwards of a billion and half jobs

If you'd like to use this gem in your app, please open a issue to express your interest and I'll publish the newer version.

## Todos

- Bump the version number and publish recent changes to rubygems.org