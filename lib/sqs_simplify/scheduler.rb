module SqsSimplify
  class Scheduler < SqsSimplify::Base
    attr_accessor :message, :attributes

    def initialize(message, attributes: nil)
      @message = message
      @attributes = attributes
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
      def mapped_queue(value)
        SqsSimplify.mapped_schedulers[name] = value
      end

      def send_message(message, **option)
        new(message, **option)
      end
    end
  end
end
