# frozen_string_literal: true

module SqsSimplify
  class Consumer < SqsSimplify::Base
    include SqsSimplify::ExecutionHook
    attr_accessor :delete_sqs_message

    def initialize(sqs_message)
      @sqs_message = sqs_message
      @message = load_message(sqs_message)
      @delete_sqs_message = true
    end

    def perform
      raise 'Must implement this method'
    end

    protected

    attr_reader :message, :sqs_message

    def delete_sqs_message?
      @delete_sqs_message
    end

    class << self
      protected

      def parallel_type
        settings[:parallel_type]
      end

      def amount_processes
        settings[:amount_processes]
      end

      private

      def consume_messages
        sqs_messages = fetch_messages
        if sqs_messages.empty?
          logger.info 'Finished without messages'
          return 0
        end

        consume_sqs_messages(sqs_messages)
      rescue Exception => e
        call_hook :resolver_exception, e, sqs_messages: sqs_messages
      ensure
        return sqs_messages&.count || 0
      end

      def consume_sqs_messages(sqs_messages)
        call_hook(:before_all, sqs_messages)
        benchmark { choose_process(sqs_messages) }
        call_hook(:after_all, sqs_messages)
      end

      def consume_sqs_message(sqs_message)
        consumer = new(sqs_message)
        call_hook(:before_each, sqs_message, consumer: consumer)

        Timeout.timeout(visibility_timeout) do
          around.is_a?(Proc) ? around.call(consumer) : consumer.perform
        end

        call_hook(:after_each, sqs_message, consumer: consumer)
      rescue TimeoutError
        consumer&.delete_sqs_message = false
      rescue Exception => e
        call_hook :resolver_exception, e, consumer: consumer
      ensure
        delete_message(sqs_message) if consumer&.delete_sqs_message
      end

      def fetch_messages(amount = 10)
        client.receive_message(
          queue_url: queue_url,
          message_attribute_names: ['All'], # Receive all custom attributes.
          max_number_of_messages: amount, # Receive at most one message.
          wait_time_seconds: 0 # Do not wait to check for the message.
        ).messages
      end

      def choose_process(messages)
        parallel_type, amount_processes =
          if %w[in_threads
                in_processes].include?(self.parallel_type.to_s) && self.amount_processes > 1 && messages.count > 1
            [self.parallel_type, self.amount_processes]
          else
            [:without_parallel, 1]
          end

        amount_parallel = [amount_processes, messages.count].min
        logger.info "Started loop with: { class_name: #{name}, #{parallel_type}: #{amount_parallel}, messages: #{messages.count} }"
        if amount_parallel == 1
          messages.each { |sqs_message| consume_sqs_message(sqs_message) }
        else
          Parallel.each(messages, parallel_type => amount_parallel) { |sqs_message| consume_sqs_message(sqs_message) }
        end
      end

      def delete_message(message)
        client.delete_message(
          queue_url: queue_url,
          receipt_handle: message.receipt_handle
        )
        true
      end

      def benchmark(&block)
        start_time = Time.now
        block.call
        logger.info "Finished in #{(Time.now - start_time).to_f} seconds"
      end

      def logger
        SqsSimplify.logger
      end

      def around(&block)
        hooks[:around] = block
      end
    end
  end
end
