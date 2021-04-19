# frozen_string_literal: true

module SqsSimplify
  class Message < OpenStruct
    def initialize(body:, queue_url:, delay_seconds: 0, **args)
      super args.merge(body: body, queue_url: queue_url, delay_seconds: delay_seconds)
    end

    def to_send
      {
        queue_url: queue_url,
        message_body: body,
        message_attributes: attributes,
        delay_seconds: delay_seconds
      }
    end
  end
end
