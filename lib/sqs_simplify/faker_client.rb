# frozen_string_literal: true

module SqsSimplify
  class FakerClient
    def send_message(sqs_message)
      id = next_id
      message = OpenStruct.new receipt_handle: id,
                               body: sqs_message[:message_body],
                               queue_url: sqs_message[:queue_url]
      pool << message
      OpenStruct.new(message_id: id)
    end

    def receive_message(queue_url:, max_number_of_messages:, **_args)
      amount =
        if max_number_of_messages.nil? || !max_number_of_messages.is_a?(Integer)
          10
        elsif max_number_of_messages.positive? && max_number_of_messages < 11
          max_number_of_messages
        end

      messages = pool.select { |message| message[:queue_url] == queue_url }[0, amount]
      OpenStruct.new(messages: messages)
    end

    def delete_message(queue_url:, receipt_handle:)
      pool.delete_if do |message|
        message.receipt_handle == receipt_handle &&
          message.queue_url == queue_url
      end
      true
    end

    def get_queue_attributes(queue_url:, **_args)
      messages = pool.select { |message| message.queue_url == queue_url }
      OpenStruct.new(attributes: {
                       'ApproximateNumberOfMessages' => messages.count,
                       'VisibilityTimeout' => 60
                     })
    end

    def get_queue_url(queue_name:)
      OpenStruct.new queue_url: "http//sqs_faker/#{queue_name}"
    end

    private

    def pool
      self.class.pool
    end

    def next_id
      self.class.next_id
    end

    class << self
      def next_id
        @next_id ||= 0
        @next_id += 1
        @next_id.to_s(16)
      end

      def pool
        @pool ||= []
      end

      def purger!
        @pool = []
      end
    end
  end
end
