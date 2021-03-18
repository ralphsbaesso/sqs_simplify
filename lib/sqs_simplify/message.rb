# frozen_string_literal: true

module SqsSimplify
  class Message < OpenStruct
    def initialize(body:, queue_url:, **args)
      super args.merge(body: body, queue_url: queue_url)
    end

    def to_send
      {
        queue_url: queue_url,
        message_body: body,
        message_attributes: attributes
      }
    end
  end
end
