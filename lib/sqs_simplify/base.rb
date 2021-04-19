# frozen_string_literal: true

require 'date'

module SqsSimplify
  class Base
    include SqsSimplify::Client

    protected

    def dump_message(value)
      self.class.dump_message value
    end

    def load_message(value)
      self.class.load_message value
    end

    class << self

      def define_queue_name(name)
        return unless name

        @name = name
        if self < SqsSimplify::Consumer
          SqsSimplify.consumers[name.to_sym] = self
        elsif self < SqsSimplify::Scheduler
          SqsSimplify.schedulers[name.to_sym] = self
        end
      end

      def define_visibility_timeout(value)
        @visibility_timeout = value
      end

      def define_message_retention_period(value)
        @message_retention_period = value
      end

      def define_delay_seconds(value)
        @delay_seconds = value
      end

      def queue_name
        return @queue_name if @queue_name

        @queue_name = [
          SqsSimplify.setting.queue_prefix,
          @name || to_underscore(self.name),
          SqsSimplify.setting.queue_suffix
        ].compact.join('_')
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
        queue_info(load: load)['queueArn']
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
        load_message = setting(:load_message) || :to_json

        case load_message
        when Proc
          load_message.call body
        when :to_json
          JSON.parse(body)
        else
          body
        end
      end

      def setting(key)
        config[key.to_s]
      end

      def create_queue_and_dead_queue
        create_queue
        create_dead_letter_queue
      end

      def create_queue
        return if find_queue_by_name(queue_name)

        visibility_timeout = @visibility_timeout || 10 * 60 # Should be between 0 seconds and 12 hours.
        message_retention_period = @message_retention_period || 14 * 24 * 60 * 60 # retention, Should be between 1 minute and 14 days.
        delay_seconds = @delay_seconds || 0

        client.create_queue(
          queue_name: queue_name,
          attributes: {
            VisibilityTimeout: visibility_timeout.to_s,
            MessageRetentionPeriod: message_retention_period.to_s,
            DelaySeconds: delay_seconds.to_s
          }
        )
      end

      def create_dead_letter_queue
        dead_queue = find_queue_by_name("#{queue_name}_dead")
        return if dead_queue

        dead_queue = client.create_queue(
          queue_name: "#{queue_name}_dead",
          attributes: {
            VisibilityTimeout: (60 * 60).to_s, # Should be between 0 seconds and 12 hours.
            MessageRetentionPeriod: (14 * 24 * 60 * 60).to_s, # retention, Should be between 1 minute and 14 days.
            DelaySeconds: '0' # delay
          }
        )

        dead_queue_url = dead_queue.queue_url
        dead_letter_queue_arn =
          client.get_queue_attributes(
            queue_url: dead_queue_url,
            attribute_names: ['QueueArn']
          ).attributes['QueueArn']

        begin
          # Use a redrive policy to specify the dead letter queue and its behavior.
          redrive_policy = {
            'maxReceiveCount' => '1', # After the queue receives the same message 1 times, send that message to the dead letter queue.
            'deadLetterTargetArn' => dead_letter_queue_arn
          }.to_json

          client.set_queue_attributes(
            queue_url: queue_url,
            attributes: {
              'RedrivePolicy' => redrive_policy
            }
          )
        rescue Aws::SQS::Errors::NonExistentQueue
          raise "A queue named '#{queue_name}' does not exist."
        end
      end

      def find_queue_by_name(name)
        client.get_queue_url(queue_name: name)
      rescue Aws::SQS::Errors::NonExistentQueue
        nil
      end

      def queue_url
        @queue_url ||= client.get_queue_url(queue_name: queue_name).queue_url
      end

      def dead_queue_url
        @dead_queue_url ||= client.get_queue_url(queue_name: "#{queue_name}_dead").queue_url
      end

      def dead_queue_to_queue(amount = nil, all: false)
        if all
          dead_queue_to_queue_loop(Float::INFINITY)
        else
          dead_queue_to_queue_loop(amount.to_i)
        end
      end

      private

      def dead_queue_to_queue_loop(amount)
        return 0 unless amount.positive?

        count = 0
        loop do
          messages = dead_queue_messages([amount, 2].min)
          return count if messages.count.zero? || count >= amount

          count += messages.count
          messages.each { |message| client.send_message(queue_url: queue_url, message_body: message[:body]) }
          delete_dead_messages(messages)
        end
      end

      def dead_queue_messages(amount)
        client.receive_message(
          queue_url: dead_queue_url,
          message_attribute_names: ['All'],
          max_number_of_messages: amount,
          wait_time_seconds: 0
        ).messages
      end

      def delete_dead_messages(messages)
        client.delete_message_batch(
          queue_url: dead_queue_url,
          entries: messages.map { |m| { id: m[:message_id], receipt_handle: m[:receipt_handle] } }
        )
        true
      end

      def config
        @config ||= {}
      end

      def to_underscore(value)
        value.gsub(/::/, '_')
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
             .tr('-', '_')
             .downcase
      end
    end
  end
end
