# frozen_string_literal: true

module SqsSimplify
  class Worker
    def initialize(**options, &callback)
      self.queues = options[:queues]
      self.priority = options[:priority]
      self.callback = callback
    end

    def perform
      valid_queues!

      if priority?
        consumer_with_priority
      else
        consumer
      end
    end

    private

    attr_accessor :queues, :priority, :callback

    def sqs_consumers
      @sqs_consumers ||= build_sqs_consumers
    end

    def build_sqs_consumers
      consumers = SqsSimplify.consumers + SqsSimplify.jobs

      if queues
        queues.map do |queue|
          consumers.find { |consumer| consumer.queue_name == queue } || Struct.new(:queue_name).new
        end
      else
        consumers
      end
    end

    def valid_queues!
      if queues
        check_option_queues!
      else
        check_has_any_consumer!
      end
    end

    def check_option_queues!
      all_queue_names = sqs_consumers.map(&:queue_name)

      invalid_queues = queues.reject do |queue|
        all_queue_names.include? queue
      end

      raise "Option queue invalid: [#{invalid_queues.join(', ')}]" if invalid_queues.length.positive?
    end

    def check_has_any_consumer!
      raise 'No queue consumers were found in this project' if sqs_consumers.length.zero?
    end

    def priority?
      priority
    end

    def consumer_with_priority
      accumulated = 0
      index = 0

      loop do
        amount = execute(sqs_consumers[index])
        if amount.positive?
          accumulated += amount
          index = 0
        else
          index += 1
          return accumulated if index >= queues.count
        end
      end
    end

    def consumer
      number_of_executions = sqs_consumers.map do |sqs_consumer|
        execute(sqs_consumer)
      end
      number_of_executions.reduce(&:+)
    end

    def execute(sqs_consumer)
      result = sqs_consumer.send :consume_messages
      callback&.call(result, sqs_consumer)
      result
    end
  end
end
