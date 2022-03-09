# frozen_string_literal: true

require 'zlib'

module SqsSimplify
  class Job < SqsSimplify::Base
    set :scheduler, true
    private_class_method :new

    def perform(*_rest, **_keyrest)
      raise 'NotImplemented'
    end

    def new_job(**options)
      self.class.new_job(**options)
    end

    def dump(parameters)
      self.class.send :_dump, parameters
    end

    class << self
      def new_job(**options)
        self::ProxyJob.new(new, **options)
      end

      def perform(*rest, **keyrest)
        new_job.perform(*rest, **keyrest)
      end

      def perform_later(*rest, **keyrest)
        new_job.perform_later(*rest, **keyrest)
      end

      def consume_messages(amount = nil)
        consumer.consume_messages amount
      end

      def scheduler
        @scheduler ||= _build_scheduler
      end

      def consumer
        @consumer ||= _build_consumer
      end

      def call_validator_parameters!(array, hash)
        _validator_parameters.call(*array, **hash)
      end

      private

      def _validator_parameters
        @_validator_parameters ||= _build_validator_parameters
      end

      def _build_validator_parameters
        parameters = new.method(:perform).parameters
        params = parameters.map do |opt, name|
          _parameters_to_args opt, name
        end

        class_eval "->(#{params.join(', ')}) {}", __FILE__, __LINE__
      end

      def _parameters_to_args(opt, name)
        case opt
        when :req
          name.to_s
        when :opt
          "#{name}=nil"
        when :rest
          "*#{name}"
        when :keyreq
          "#{name}:"
        when :key
          "#{name}:nil"
        when :keyrest
          "**#{name}"
        when :block
          "&#{name}"
        end
      end

      def inherited(sub)
        super

        if sub.superclass == SqsSimplify::Job
          sub.set :scheduler, true
        else
          sub.instance_variable_set :@settings, settings.clone
        end
      end

      def _execute(args)
        class_name = args['class']
        array_params, hash_params = _read_parameters args['parameters']

        source = const_get(class_name)
        instance = source.send :new
        instance.send(:perform, *array_params, **hash_params)
      end

      def _read_parameters(parameters)
        args = _load(parameters)
        [args[:array], args[:hash]]
      end

      def _build_scheduler
        klass = _build_sub_class 'Scheduler'
        klass.private_class_method :send_message
        klass
      end

      def _build_consumer
        klass = _build_sub_class 'Consumer'
        klass.define_method(:perform) { SqsSimplify::Job.send :_execute, message }
        klass
      end

      def _build_sub_class(module_name)
        class_eval <<~M, __FILE__, __LINE__ + 1
          class #{self}::#{module_name}Job < SqsSimplify::#{module_name}
            def self.settings
              #{self}.settings
            end

            def self.client
              #{self}.client
            end

            def self.queue_name
              #{self}.queue_name
            end
          end
        M

        const_get "#{self}::#{module_name}Job"
      end

      def _dump(value)
        Base64.encode64(Zlib::Deflate.deflate(Marshal.dump(value)))
      end

      def _load(value)
        Marshal.load(Zlib::Inflate.inflate(Base64.decode64(value)))
      end
    end

    class ProxyJob
      def initialize(job, **options)
        @job = job
        @after = options[:after]
        @queue_url = options[:queue_url]
      end

      def perform(*array, **hash)
        @job.perform(*array, **hash)
        :executed
      end

      def perform_later(*array, **hash)
        return perform(*array, **hash) unless scheduler?

        @job.class.call_validator_parameters! array, hash
        message = {
          'class' => @job.class.name,
          'parameters' => @job.dump(array: array, hash: hash)
        }

        send_message message
      end

      private

      def send_message(message)
        @job.class.scheduler.send(:send_message, message: message, after: @after, queue_url: @queue_url)
      end

      def respond_to_missing?(symbol, value = nil)
        @job.respond_to? symbol, value
      end

      def method_missing(symbol, *rest, **keyrest)
        @job.send symbol, *rest, **keyrest
      end

      def scheduler?
        SqsSimplify::Job.settings[:scheduler] && @job.class.settings[:scheduler]
      end
    end
  end
end
