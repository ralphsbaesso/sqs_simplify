# frozen_string_literal: true

module SqsSimplify
  class Consumer < SqsSimplify::Base
    include SqsSimplify::ExecutionHook
    private_class_method :new

    class << self
      def consume_message(_message)
        raise 'Must implement this method'
      end

      private

      def fetch_messages(amount = 10)
        client.receive_message(
          queue_url: queue_url,
          message_attribute_names: ['All'], # Receive all custom attributes.
          max_number_of_messages: amount, # Receive at most one message.
          wait_time_seconds: 0 # Do not wait to check for the message.
        ).messages
      end

      def delete_message(message)
        client.delete_message(
          queue_url: queue_url,
          receipt_handle: message.receipt_handle
        )
        true
      end
    end
  end
end
