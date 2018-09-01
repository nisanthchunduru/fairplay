require "spec_helper"

class Integer
  def minutes
    self * 60
  end
end

describe Fairplay do
  describe ".enqueue" do
    context "sidekiq worker doesn't have any rate limit policies" do
      class StoreMessageInSearchIndex
        include Sidekiq::Worker

        def perform(message_id)
        end
      end

      let(:message_id) { 1 }

      it "enqueues the job immediately" do
        flexmock(Sidekiq::Client).should_receive(:enqueue).with(StoreMessageInSearchIndex, message_id).once
        Fairplay.enqueue(StoreMessageInSearchIndex, message_id)
      end
    end

    context "sidekiq worker has a rate limit policy" do
      let(:account_id) { 1 }

      class ExportData
        include Sidekiq::Worker

          class RateLimitOnAccountId < Fairplay::RateLimitPolicy
            limit 2
            period 15.minutes
            penalty 30.minutes
            
            def account_id(job_args)
              job_args.first
            end
          end

        def perform(account_id)
        end
      end

      context "a new job exceeds the rate limit" do
        it "rate limits the job" do
          time_now = Time.new(2018, 1, 1)
          Timecop.freeze(time_now)

          flexmock(Sidekiq::Client).should_receive(:enqueue).with(ExportData, account_id).twice
          Fairplay.enqueue(ExportData, account_id)
          Fairplay.enqueue(ExportData, account_id)
          penalty = 30.minutes
          flexmock(Sidekiq::Client).should_receive(:enqueue_in).with(penalty, ExportData, account_id).once
          Fairplay.enqueue(ExportData, account_id)
        end
      end
    end
  end
end
