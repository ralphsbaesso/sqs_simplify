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

    def queue_url
      self.class.queue_url
    end

    def send_message(**options)
      sqs_message = Message.new queue_url: queue_url,
                                body: dump_message(message),
                                **options

      self.class.call_hook :before_each, sqs_message
      client.send_message(sqs_message.to_send).message_id
    rescue StandardError => e
      self.class.call_hook :resolver_exception, e, sqs_message: sqs_message
    ensure
      self.class.call_hook :after_each, sqs_message
    end

    private_class_method :new

    class << self
      def send_message(message)
        new(message)
      end

      def map_queue(nickname, queue_name: nil)
        const_name = nickname.capitalize

        class_eval <<~M, __FILE__, __LINE__ + 1
          class #{const_name} < #{self}
            define_queue_name(#{queue_name ? "\"#{queue_name}\"" : 'nil'})
          end

          private_constant '#{const_name}'
          def self.#{nickname}
            #{const_name}
          end
        M

        mapped_queues[nickname] = const_get(const_name).name
      end

      private

      def mapped_queues
        @mapped_queues ||= {}
      end
    end
  end
end
