# frozen_string_literal: true

module SqsSimplify
  module Errors
    class NonExistentQueue < StandardError
      def initialize(queue_full_name)
        super "The queue `#{queue_full_name}' does not exist."
      end
    end
  end
end
