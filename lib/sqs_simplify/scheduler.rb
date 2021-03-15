# frozen_string_literal: true

module SqsSimplify
  class Scheduler < SqsSimplify::Base
    include SqsSimplify::ExecutionHook
    attr_accessor :message, :attributes

    def initialize(message)
      @message = message
    end

    def now
      send_message
    end

    def later(seconds)
      raise 'parameter must be a Integer' unless seconds.is_a? Integer
      raise 'parameter must be between 1 to 960 seconds' unless seconds.positive? &&
                                                                seconds < 961

      send_message(delay_seconds: seconds)
    end

    private

    def send_message(**option)
      sqs_message = {
        queue_url: queue_url,
        message_body: dump_message(message),
        message_attributes: attributes
      }.merge(option).compact

      client.send_message(sqs_message).message_id
    end

    private_class_method :new

    class << self
      def send_message(message)
        new(message)
      end

      def map_queue(queue_name, queue_url)
        name = queue_name.to_s
        mapped_queues[name] = queue_url
        const_name = name.capitalize

        class_eval <<~M, __FILE__, __LINE__ + 1
          class #{const_name} < #{self}
            default_url '#{queue_url}'
          end

          private_constant '#{const_name}'
          def self.#{name}
            #{const_name}
          end
        M
      end

      private

      def mapped_queues
        @mapped_queues ||= {}
      end
    end
  end
end
