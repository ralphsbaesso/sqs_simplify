module SqsSimplify
  class Worker
    attr_accessor :class_name, :threads

    def initialize(class_name:, threads: 1)
      @class_name = class_name
      @threads = threads
    end

    def work
      klass = Object.const_get(class_name)
      messages = klass.send :fetch_messages
      self.class.call_hook(:before_all, messages)

      start_time = Time.now
      logger.info "Started loop with: { class_name: #{klass.name}, threads: #{threads}, messages: #{messages.count} }"

      if messages.present?
        Parallel.map(messages, in_threads: threads) do |message|
          self.class.call_hook(:before_each, message)
          klass.consume_message(message)
          klass.send :delete_message, message
          self.class.call_hook(:after_each, message)
        end
        logger.info "Finished in #{(Time.now - start_time).to_f} seconds"
        self.class.call_hook(:after_all)
        messages.count
      else
        logger.info 'Finished without messages'
        0
      end
    rescue Exception => e
      logger.warn e.message
      logger.warn e.backtrace.join("\n")
      self.class.call_hook :resolver_exception, e, messages
      messages&.count || 0
    end

    private

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

      def after(time = :each, &block)
        time = "after_#{time}".to_sym
        hooks[time] = block
      end

      def before(time = :each, &block)
        time = "before_#{time}".to_sym
        hooks[time] = block
      end

      def call_hook(time, arg = nil, *args)
        block = hooks[time.to_sym]
        block.call(arg, *args) if block.is_a?(Proc)
      end

      def hooks
        @hooks ||= {}
      end

      def resolver_exception(&block)
        hooks[:resolver_exception] = block
      end

      def logger
        SqsSimplify.logger
      end
    end
  end
end
