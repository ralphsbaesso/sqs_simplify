# frozen_string_literal: true

module SqsSimplify
  class DeadQueue < SqsSimplify::Base
    VISIBILITY_TIMEOUT = 60 * 60
    MESSAGE_RETENTION_PERIOD = 14 * 24 * 60 * 60
    DELAY_SECONDS = 0

    class << self
      undef_method :max_receive_count

      def main_queue
        @main_queue ||= const_get(name.gsub('::DeadQueue', ''))
      end

      def create_queue
        dead_queue = find_queue_by_name(queue_full_name)
        dead_queue ||= super

        # Use a redrive policy to specify the dead letter queue and its behavior.
        redrive_policy = {
          'maxReceiveCount' => main_queue.max_receive_count.to_s, # After the queue receives the same message 1 times, send that message to the dead letter queue.
          'deadLetterTargetArn' => queue_arn
        }.to_json

        main_queue.update_attributes(RedrivePolicy: redrive_policy)
        dead_queue
      end

      def send_message_to_main_queue(amount)
        raise "Invalid argument #{amount}" unless amount.is_a?(Numeric) ||
                                                  amount.positive?

        dead_queue_to_queue_loop(amount)
      end

      private

      def dead_queue_to_queue_loop(amount)
        count = 0

        loop do
          messages = dead_queue_messages([amount, 10].min)
          count += messages.count

          messages.each do |message|
            client.send_message(queue_url: main_queue.queue_url, message_body: message[:body])
            client.delete_message(queue_url: queue_url, receipt_handle: message.receipt_handle)
          end

          return count if messages.count.zero? || count >= amount
        end
      end

      def dead_queue_messages(amount)
        client.receive_message(
          queue_url: queue_url,
          message_attribute_names: ['All'],
          max_number_of_messages: amount,
          wait_time_seconds: 0
        ).messages
      end
    end
  end
end
