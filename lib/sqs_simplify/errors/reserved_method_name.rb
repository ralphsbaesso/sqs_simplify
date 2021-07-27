# frozen_string_literal: true

module SqsSimplify
  module Errors
    class ReservedMethodName < StandardError
      def initialize(method)
        super "reserved method name `#{method}'."
      end
    end
  end
end
