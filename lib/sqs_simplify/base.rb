# frozen_string_literal: true

require 'date'

module SqsSimplify
  class Base
    include SqsSimplify::Client

    VISIBILITY_TIMEOUT = 10 * 60
    MESSAGE_RETENTION_PERIOD = 14 * 24 * 60 * 60
    DELAY_SECONDS = 0

    protected

    def dump_message(value)
      self.class.dump_message value
    end

    def load_message(value)
      self.class.load_message value
    end

    class << self
      def set(key, value)
        settings[key.to_sym] = value
      end

      def queue_name
        @queue_name ||= (settings[:queue_name] || to_underscore(name)).to_s
      end

      def queue_full_name
        @queue_full_name ||= build_queue_full_name
      end

      def queue_url
        @queue_url ||= client.get_queue_url(queue_name: queue_full_name).queue_url
      rescue Aws::SQS::Errors::NonExistentQueue
        raise SqsSimplify::Errors::NonExistentQueue, queue_full_name
      end

      def dead_queue
        @dead_queue ||= build_dead_queue_class
      end

      def count_messages
        approximate_number_of_messages(load: true)
      end

      def approximate_number_of_messages(load: false)
        queue_info(load: load)['ApproximateNumberOfMessages'].to_i
      end

      def queue_info(load: false)
        @queue_info = nil if load
        @queue_info ||= client.get_queue_attributes(queue_url: queue_url, attribute_names: ['All']).attributes
      end

      def queue_arn(load: false)
        queue_info(load: load)['QueueArn']
      end

      def approximate_number_of_messages_not_visible(load: false)
        queue_info(load: load)['ApproximateNumberOfMessagesNotVisible'].to_i
      end

      def created_at(load: false)
        DateTime.strptime(queue_info(load: load)['CreatedTimestamp'], '%s')
      end

      def updated_at(load: false)
        DateTime.strptime(queue_info(load: load)['LastModifiedTimestamp'], '%s')
      end

      def visibility_timeout(load: false)
        queue_info(load: load)['VisibilityTimeout'].to_i
      end

      def message_retention_period(load: false)
        queue_info(load: load)['MessageRetentionPeriod'].to_i
      end

      def max_receive_count
        @max_receive_count ||= build_max_receive_count
      end

      def dump_message(value)
        dump_message = settings[:dump_message] || :to_json

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
        load_message = settings[:load_message] || :to_json

        case load_message
        when Proc
          load_message.call body
        when :to_json
          JSON.parse(body)
        else
          body
        end
      end

      def settings
        @settings ||= {}
      end

      def create_queue_and_dead_queue
        create_queue
        dead_queue.create_queue
        true
      end

      def create_queue
        queue = find_queue_by_name(queue_full_name)
        return queue if queue

        client.create_queue(
          queue_name: queue_full_name,
          attributes: default_attributes
        )
      end

      def find_queue_by_name(name)
        client.get_queue_url(queue_name: name)
      rescue Aws::SQS::Errors::NonExistentQueue
        nil
      end

      def update_attributes(**attributes)
        attributes = attributes.map { |att| att.map(&:to_s) }.to_h
        client.set_queue_attributes(
          queue_url: queue_url,
          attributes: attributes
        )
        true
      end

      private

      def build_queue_full_name
        [
          SqsSimplify.settings.queue_prefix,
          queue_name,
          SqsSimplify.settings.queue_suffix
        ].compact.join('_')
      end

      def build_dead_queue_class
        class_name = "::#{name}::DeadQueue"

        class_eval <<~M, __FILE__, __LINE__ + 1
          class #{class_name} < SqsSimplify::DeadQueue; end
        M

        dead_queue_class = const_get class_name
        dead_queue_class.set :queue_name, "#{queue_name}_dead"
        dead_queue_class
      end

      def build_max_receive_count
        value = settings[:max_receive_count].to_i
        value.positive? ? value : 1
      rescue StandardError
        1
      end

      def default_attributes
        visibility_timeout = settings[:visibility_timeout] || self::VISIBILITY_TIMEOUT # Should be between 0 seconds and 12 hours.
        message_retention_period = settings[:message_retention_period] || self::MESSAGE_RETENTION_PERIOD # retention, Should be between 1 minute and 14 days.
        delay_seconds = settings[:delay_seconds] || self::DELAY_SECONDS

        {
          VisibilityTimeout: visibility_timeout.to_s,
          MessageRetentionPeriod: message_retention_period.to_s,
          DelaySeconds: delay_seconds.to_s
        }
      end

      def to_underscore(value)
        value.gsub(/::/, '_')
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
             .tr('-', '_')
             .downcase
      end

      def inherited(sub)
        super
        return if sub.name.nil?
        return if %w[SqsSimplify::Job SqsSimplify::Consumer SqsSimplify::Scheduler].include? sub.name

        if %w[SqsSimplify::Consumer SqsSimplify::Job].include? sub.superclass.name
          SqsSimplify.consumers << sub
        elsif sub < SqsSimplify::Scheduler
          SqsSimplify.schedulers << sub
        end
      end
    end
  end
end
