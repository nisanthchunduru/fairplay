require "spec_helper"

class Integer
  def minutes
    self * 60
  end
end

describe Fairplay do
  describe ".enqueue" do
    context "the sidekiq worker doesn't have any rate limit policies" do
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

    context "the sidekiq worker has a rate limit policy" do
      let(:account_id) { 1 }

      class ExportData
        include Sidekiq::Worker

        class RateLimitOnAccountId < Fairplay::RateLimitPolicy
          limit 6
          period 10.minutes
          penalty 3.minutes
        end

        def account_id(account_id)
          account_id
        end

        def perform(account_id)
        end
      end

      context "a new job exceeds the rate limit" do
        let(:time_now) { Time.new(2100, 1, 1) }
        let(:limit) { ExportData::RateLimitOnAccountId.limit }
        let(:penalty) { ExportData::RateLimitOnAccountId.penalty }

        it "enqueues the job with a delay of 30 minutes (the penalty time)" do
          Timecop.freeze(time_now)

          flexmock(Sidekiq::Client).should_receive(:enqueue).with(ExportData, account_id).times(limit)
          limit.times do
            Fairplay.enqueue(ExportData, account_id)
            Timecop.freeze(Time.now + 15.seconds)
          end
          flexmock(Sidekiq::Client).should_receive(:enqueue_at).with(Time.now + penalty, ExportData, account_id).once
          Fairplay.enqueue(ExportData, account_id)
        end

        context "another new job arrives in the same rate limit period" do
          it "enqueues the job with a delay of 30 minutes (the penalty) time since the rate limited job was enqueued" do
            Timecop.freeze(time_now)

            flexmock(Sidekiq::Client).should_receive(:enqueue).with(ExportData, account_id).times(limit)
            limit.times do
              Fairplay.enqueue(ExportData, account_id)
              Timecop.freeze(Time.now + 10.seconds)
            end
            enqueue_time = Time.now + penalty
            flexmock(Sidekiq::Client).should_receive(:enqueue_at).with(enqueue_time, ExportData, account_id).once
            Fairplay.enqueue(ExportData, account_id)
            last_rate_limited_job_enqueue_time = enqueue_time
            Timecop.freeze(Time.now + 1.minute)
            enqueue_time = last_rate_limited_job_enqueue_time + penalty
            flexmock(Sidekiq::Client).should_receive(:enqueue_at).with(enqueue_time, ExportData, account_id).once
            Fairplay.enqueue(ExportData, account_id)
          end
        end
      end
    end
  end
end
