# frozen_string_literal: true

module SqsSimplify
  class Message
    attr_accessor :body, :delay_seconds, :queue_url

    def initialize(body:, queue_url:, delay_seconds: 0)
      self.body = body
      self.delay_seconds = delay_seconds
      self.queue_url = queue_url
    end

    def to_send
      {
        queue_url: queue_url,
        message_body: body,
        delay_seconds: delay_seconds
      }
    end
  end
end
