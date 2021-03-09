module SqsSimplify
  class Consumer < SqsSimplify::Base
    private_class_method :new

    class << self
      def consume_message(_message)
        raise 'Must implement this method'
      end

      private

      def mapped_queue(value)
        SqsSimplify.mapped_consumers[name] = value
      end

      def fetch_messages(amount = 10)
        receive_message_result = client.receive_message(
          queue_url: queue_url,
          message_attribute_names: ['All'], # Receive all custom attributes.
          max_number_of_messages: amount, # Receive at most one message.
          wait_time_seconds: 0 # Do not wait to check for the message.
        )

        receive_message_result.messages.map do |message|
          message[:body] = load_message(message[:body])
          message
        end
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
