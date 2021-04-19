# frozen_string_literal: true

module SqsSimplify
  class Worker
    class << self
      def work
        consumers = SqsSimplify.consumers
        raise 'Consumers not configured' unless consumers.present?

        amount = consumers.values.map do |consumer|
          consumer.send :consume_messages
        end
        amount.reduce(&:+)
      end
    end
  end
end
