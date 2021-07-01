# frozen_string_literal: true

module SqsSimplify
  class Job < SqsSimplify::Base
    private_class_method :new

    class << self
      def consume_messages
        consumer.consume_messages
      end

      def scheduler
        @scheduler ||= build_scheduler
      end

      def consumer
        @consumer ||= build_consumer
      end

      private

      def schedule(method, *parameters)
        message = { 'method' => method, 'parameters' => dump(parameters) }
        if scheduler?
          scheduler.send :send_message, message
        else
          execute(message)
          FakeScheduler.new
        end
      end

      def scheduler?
        settings[:scheduler]
      end

      def execute(args)
        method = args['method']
        parameters = load(args['parameters'])
        new.send method, *parameters
      end

      def inherited(sub)
        super
        sub.set :scheduler, true
      end

      def method_added(method)
        origin_file, definition_line = instance_method(method).source_location
        method_signature = IO.readlines(origin_file)[definition_line.pred].gsub("\n", '').strip
        parameters = build_parameters(method_signature)

        class_eval <<~M, __FILE__, __LINE__ + 1
          class << self
            #{method_signature}
              schedule :#{method} #{parameters}
            end
          end
        M
      end

      def build_parameters(str)
        keys = build_keys(str)
        return keys if keys == ''

        parameters = keys_to_parameters(keys)
        ", #{parameters.join(', ')}"
      end

      def build_keys(str)
        index = str.index('(')
        return '' if index.nil?

        str[index + 1..-2].split(',')
      end

      def keys_to_parameters(keys)
        keys.map do |key|
          if key.include?('=')
            str = key.split('=')[0].strip
            "#{str} = #{str}"
          elsif key.include?(':')
            str = key.split(':')[0].strip
            "#{str}: #{str}"
          else
            key
          end
        end
      end

      def build_scheduler
        klass = Class.new(SqsSimplify::Scheduler)
        klass.private_class_method :send_message
        transfer_settings(klass)
        klass
      end

      def build_consumer
        klass = Class.new(SqsSimplify::Consumer) do
          def perform
            self.class.father_job.send :execute, message
          end
        end
        transfer_settings(klass)
        klass
      end

      def transfer_settings(sub)
        sub.instance_variable_set :@settings, settings
        current_job = self
        sub.define_singleton_method :father_job do
          current_job
        end
      end

      def dump(value)
        Base64.encode64(Zlib::Deflate.deflate(Marshal.dump(value)))
      end

      def load(value)
        Marshal.load(Zlib::Inflate.inflate(Base64.decode64(value)))
      end
    end
  end

  class FakeScheduler
    def now
      :executed
    end

    def later(_value = nil)
      :executed
    end
  end
end
