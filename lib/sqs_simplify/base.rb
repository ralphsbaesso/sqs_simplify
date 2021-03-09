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
      def set(key, value)
        mapped_queue(value) if key.to_s == 'queue_url'
        config[key.to_s] = value
      end

      def setting(key)
        config[key.to_s]
      end

      def queue_url
        setting :queue_url
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

      def load_message(value)
        dump_message = setting(:dump_message) || :to_json

        case dump_message
        when Proc
          dump_message.call value
        when :to_json
          value.to_json
        else
          value
        end
      end

      private

      def config
        @config ||= {}
      end
    end
  end
end
