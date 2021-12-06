# frozen_string_literal: true

require 'zlib'

module SqsSimplify
  class Job < SqsSimplify::Base
    set :scheduler, true
    private_class_method :new

    class << self
      def consume_messages(amount = nil)
        consumer.consume_messages amount
      end

      def scheduler
        @scheduler ||= _build_scheduler
      end

      def consumer
        @consumer ||= _build_consumer
      end

      private

      def inherited(sub)
        super

        if sub.superclass == SqsSimplify::Job
          sub.set :scheduler, true
        else
          _transfer_settings(sub)
        end
      end

      def method_added(method)
        super
        return if private_instance_methods.include? method

        _add_method method
      end

      def _schedule(method, *parameters)
        message = { 'class' => name, 'method' => method, 'parameters' => _dump(parameters) }
        ProxyScheduler.new(self, message)
      end

      def _execute(args)
        method = args['method']
        class_name = args['class']
        array_params, hash_params = _read_parameters args['parameters']

        source = const_get(class_name)
        instance = source.send :new
        hash_params ? instance.send(method, *array_params, **hash_params) : instance.send(method, *array_params)
      end

      def _read_parameters(parameters)
        parameters = _load(parameters)

        if parameters.last.is_a? Hash
          hash = parameters.pop
          [parameters, hash]
        else
          [parameters]
        end
      end

      def _add_method(method)
        _check_reserved_method_name!(method)
        origin_file, definition_line = instance_method(method).source_location
        method_signature = IO.readlines(origin_file)[definition_line.pred].gsub("\n", '').strip
        return unless method_signature.start_with? 'def '

        parameters = _build_parameters(method_signature)

        class_eval <<~M, __FILE__, __LINE__ + 1
          class << self
            #{method_signature}
              _schedule :#{method} #{parameters}
            end
          end
        M
      end

      def _build_parameters(str)
        keys = _build_keys(str)
        return keys if keys == ''

        parameters = _keys_to_parameters(keys)
        ", #{parameters.join(', ')}"
      end

      def _build_keys(str)
        index = str.index('(')
        return '' if index.nil?

        str[index + 1..-2].split(',')
      end

      def _keys_to_parameters(keys)
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

      def _build_scheduler
        klass = Class.new(SqsSimplify::Scheduler)
        klass.private_class_method :send_message
        _transfer_settings(klass, clone_settings: false)
        klass
      end

      def _build_consumer
        klass = Class.new(SqsSimplify::Consumer) do
          def perform
            SqsSimplify::Job.send :_execute, message
          end
        end
        _transfer_settings(klass, clone_settings: false)
        klass
      end

      def _transfer_settings(sub, clone_settings: true)
        sub.instance_variable_set :@settings, clone_settings ? settings.clone : settings
        sub.instance_variable_set :@client, client
        sub.set :queue_name, queue_name
      end

      def _dump(value)
        Base64.encode64(Zlib::Deflate.deflate(Marshal.dump(value)))
      end

      def _load(value)
        Marshal.load(Zlib::Inflate.inflate(Base64.decode64(value)))
      end

      def _check_reserved_method_name!(method)
        if SqsSimplify::Job.methods.map(&:to_s).include? method.to_s
          raise SqsSimplify::Errors::ReservedMethodName,
                method
        end
      end
    end

    class ProxyScheduler
      def initialize(job, message)
        @message = message
        @job = job
      end

      def later(seconds = nil)
        if scheduler?
          @job.scheduler.send(:send_message, message: @message, after: seconds)
        else
          now
        end
      end

      def now
        @job.send :_execute, @message
        :executed
      end

      private

      def scheduler?
        SqsSimplify::Job.settings[:scheduler] && @job.settings[:scheduler]
      end
    end
  end
end
