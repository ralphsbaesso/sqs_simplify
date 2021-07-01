# frozen_string_literal: true

module SqsSimplify
  class Consumer < SqsSimplify::Base
    include SqsSimplify::ExecutionHook
    attr_accessor :delete_sqs_message
    attr_reader :visibility_timeout, :errors

    def initialize(sqs_message, visibility_timeout)
      @sqs_message = sqs_message
      @message = load_message(sqs_message)
      @visibility_timeout = visibility_timeout
      @delete_sqs_message = visibility_timeout.positive?
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
      def consume_messages(amount = 10)
        visibility_timeout # load
        sqs_messages = fetch_messages(amount)
        consume_sqs_messages(sqs_messages, Time.now)
      rescue Exception => e
        call_hook :resolver_exception, e, sqs_messages
      ensure
        return sqs_messages&.count || 0
      end

      def message_not_deleted(&block)
        hooks[:message_not_deleted] = block
      end

      def around(&block)
        hooks[:around] = block
      end

      protected

      def parallel_type
        settings[:parallel_type]
      end

      def amount_processes
        settings[:amount_processes]
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

      def consume_sqs_messages(sqs_messages, start_time)
        call_hook(:before_all, sqs_messages)
        benchmark { choose_process(sqs_messages, start_time) }
        call_hook(:after_all, sqs_messages)
      end

      def choose_process(messages, start_time)
        parallel_type, amount_processes = build_parallel_parameter(messages)

        logger.info "Started loop with: { class_name: #{name}, #{parallel_type}: #{amount_processes}, messages: #{messages.count} }"
        if amount_processes == 1
          messages.each { |sqs_message| consume_sqs_message(sqs_message, start_time) }
        else
          Parallel.each(messages, parallel_type => amount_processes) do |sqs_message|
            consume_sqs_message(sqs_message, start_time)
          end
        end
      end

      def build_parallel_parameter(messages)
        process_in_parallel = %w[in_threads in_processes].include?(parallel_type.to_s) &&
                              amount_processes > 1 &&
                              messages.count > 1

        process_in_parallel ? [parallel_type, amount_processes] : [:without_parallel, 1]
      end

      def consume_sqs_message(sqs_message, start_time)
        time_left = build_time_left(start_time)
        consumer = new(sqs_message, time_left)
        call_hook(:before_each, consumer)

        Timeout.timeout(time_left) do
          around.is_a?(Proc) ? around.call(consumer) : consumer.perform
        end
      rescue Exception => e
        if consumer
          consumer.delete_sqs_message = false
          consumer.instance_variable_set :@errors, ["Exception: #{e.message}"] + e.backtrace
        end
        call_hook :resolver_exception, e, consumer
      ensure
        call_hook(:after_each, consumer)
        delete_message(consumer)
      end

      def build_time_left(start_time)
        time_left = visibility_timeout - (Time.now - start_time).to_f
        time_left = -0.1 if time_left.zero?
        [time_left, 0.1].max
      end

      def delete_message(consumer)
        if consumer&.delete_sqs_message
          delete_sqs_message(consumer.send(:sqs_message))
        else
          call_hook :message_not_deleted, consumer
        end
      end

      def delete_sqs_message(message)
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
    end
  end
end
