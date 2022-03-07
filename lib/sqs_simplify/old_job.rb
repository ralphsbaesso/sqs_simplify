# frozen_string_literal: true

# Override to ruby version < 3.0.0
module SqsSimplify
  class Job
    class << self
      def call_validator_parameters!(parameters)
        _validator_parameters.call(*parameters)
      end

      def _execute(args)
        class_name = args['class']
        parameters = _load args['parameters']

        source = const_get(class_name)
        instance = source.send :new
        instance.perform(*parameters)
      end

      def _ruby_version_notification?
        @ruby_version_notification || SqsSimplify.settings.disable_ruby_version_notification
      end

      def _disable_ruby_version_notification!
        @ruby_version_notification = true
      end
    end

    class ProxyJob
      def perform(*parameters)
        show_alert unless SqsSimplify::Job._ruby_version_notification?

        @job.perform(*parameters)
        :executed
      end

      def perform_later(*parameters)
        show_alert unless SqsSimplify::Job._ruby_version_notification?
        return perform(*parameters) unless scheduler?

        @job.class.call_validator_parameters! parameters
        message = {
          'class' => @job.class.name,
          'parameters' => @job.dump(parameters)
        }
        @job.class.scheduler.send(:send_message, message: message, after: @after)
      end

      private

      def method_missing(symbol, *rest)
        @job.send symbol, *rest
      end

      def show_alert
        warn "\t#####################################################################"
        warn "\tATTENTION!"
        warn "\tPor projects with lower version ruby 3"
        warn "\tThis library was developed for versions higher than 3"
        warn "\tTo not show the notification:"
        warn "\tSqsSimplify.settings.disable_ruby_version_notification = true"
        warn "\t#####################################################################"
        puts
        SqsSimplify::Job._disable_ruby_version_notification!
      end
    end
  end
end
