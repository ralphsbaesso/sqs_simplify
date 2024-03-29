# frozen_string_literal: true

module SqsSimplify
  module ExecutionHook
    module ClassMethods
      def after(type = :each, &block)
        type = "after_#{type}".to_sym
        hooks[type] = block
      end

      def before(type = :each, &block)
        type = "before_#{type}".to_sym
        hooks[type] = block
      end

      def call_hook(type, arg = nil, args = {})
        block = hooks[type.to_sym]
        SqsSimplify.call_hook(type, arg, args) unless self == SqsSimplify
        block&.call(arg, args)
      end

      def hooks
        @hooks ||= {}
      end

      def resolver_exception(&block)
        hooks[:resolver_exception] = block
      end

      def add_hook(hook_name, *hook_names)
        hook_names.unshift(hook_name)
        hook_names.each do |name|
          define_singleton_method(name) do |&block|
            hooks[name.to_sym] = block
          end
        end
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end
