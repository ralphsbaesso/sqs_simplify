# frozen_string_literal: true

module SqsSimplify
  class Base
    include SqsSimplify::Client

    def queue_url
      self.class.queue_url
    end

    protected

    def dump_message(value)
      self.class.dump_message value
    end

    def load_message(value)
      self.class.dump_message value
    end

    class << self
      attr_reader :queue_url

      def default_url(queue_url)
        @queue_url = queue_url
      end

      def count_messages
        approximate_number_of_messages
      end

      def approximate_number_of_messages
        queue_info['ApproximateNumberOfMessages'].to_i
      end

      def queue_info
        client.get_queue_attributes(queue_url: queue_url, attribute_names: ['All']).attributes
      end

      def dump_message(value)
        dump_message = setting(:dump_message) || :to_json

        case dump_message
        when Proc
          dump_message.call value
        when :to_json
          value.to_json
        else
          value.to_s
        end
      end

      def load_message(message)
        body = message.body
        dump_message = setting(:dump_message) || :to_json

        case dump_message
        when Proc
          dump_message.call body
        when :to_json
          JSON.parse(body)
        else
          body
        end
      end

      def setting(key)
        config[key.to_s]
      end

      private

      def config
        @config ||= {}
      end
    end
  end
end
