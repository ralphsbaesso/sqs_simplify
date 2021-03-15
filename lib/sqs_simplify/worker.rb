# frozen_string_literal: true

module SqsSimplify
  class Worker
    include SqsSimplify::ExecutionHook
    attr_accessor :class_name, :threads

    def initialize(class_name:, threads: 1)
      @class_name = class_name
      @threads = threads
    end

    def work
      @klass = Object.const_get(class_name)
      messages = @klass.send :fetch_messages
      call_hook(:before_all, messages)

      start_time = Time.now
      logger.info "Started loop with: { class_name: #{@klass.name}, threads: #{threads}, messages: #{messages.count} }"

      amount_threads = [threads, messages.count].min
      if messages.present?
        Parallel.map(messages, in_threads: amount_threads) do |message|
          call_hook(:before_each, message)
          body = @klass.load_message(message)
          @klass.consume_message(body)
          @klass.send :delete_message, message
          call_hook(:after_each, message)
        end

        logger.info "Finished in #{(Time.now - start_time).to_f} seconds"
      else
        logger.info 'Finished without messages'
      end

      call_hook(:after_all, messages)
    rescue Exception => e
      logger.warn e.message
      logger.warn e.backtrace.join("\n")
      call_hook :resolver_exception, e, messages
    ensure
      messages&.count || 0
    end

    private

    def call_hook(type, arg = nil, *args)
      self.class.call_hook(type, arg, args)
      @klass.call_hook(type, arg, args)
    end

    def logger
      self.class.logger
    end

    class << self
      attr_accessor :consumers

      def work
        raise 'Consumers not configured' unless consumers.present?

        amount = consumers.map do |consumer|
          class_name = consumer[:class_name] || consumer['class_name']
          threads = consumer[:threads] || consumer['threads']
          new(class_name: class_name, threads: threads).work
        end
        amount.reduce(&:+)
      end

      def logger
        SqsSimplify.logger
      end
    end
  end
end
