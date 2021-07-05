# frozen_string_literal: true

module SqsSimplify
  class Scheduler < SqsSimplify::Base
    include SqsSimplify::ExecutionHook
    private_class_method :new

    def initialize(message, delay_seconds)
      @message = message
      @delay_seconds = delay_seconds
    end

    private

    attr_accessor :message, :delay_seconds

    def queue_url
      self.class.queue_url
    end

    def send_message
      sqs_message = Message.new queue_url: queue_url, body: dump_message(message), delay_seconds: delay_seconds
      self.class.call_hook :before_each, sqs_message
      client.send_message(sqs_message.to_send).message_id
    rescue Aws::SQS::Errors::NonExistentQueue => e
      self.class.call_hook :resolver_exception, e, sqs_message
      raise e
    rescue StandardError => e
      self.class.call_hook :resolver_exception, e, sqs_message
    ensure
      self.class.call_hook :after_each, sqs_message
    end

    class << self
      def send_message(message:, after: nil)
        after = after.nil? ? 0 : after.to_i
        raise 'parameter must be between 0 to 960 seconds' unless after >= 0 && after < 961

        new(message, after).send :send_message
      end

      def map_queue(nickname, &block)
        const_name = nickname.capitalize

        class_eval <<~M, __FILE__, __LINE__ + 1
          class #{const_name} < #{self}; end
          private_constant '#{const_name}'

          def self.#{nickname}
            #{const_name}
          end
        M

        block&.call send(nickname)
        mapped_queues[nickname] = const_get(const_name).name
      end

      private

      def mapped_queues
        @mapped_queues ||= {}
      end
    end
  end
end
