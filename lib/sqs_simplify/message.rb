# frozen_string_literal: true

module SqsSimplify
  class Message
    attr_accessor :body, :delay_seconds, :queue_url, :message_group_id

    def initialize(body:, queue_url:, delay_seconds: 0, message_group_id: nil)
      self.body = body
      self.delay_seconds = delay_seconds
      self.queue_url = queue_url
      self.message_group_id = message_group_id
    end

    def to_send
      hash = {
        queue_url: queue_url,
        message_body: body,
        delay_seconds: delay_seconds
      }
      hash[:message_group_id] = message_group_id.to_s if message_group_id
      hash
    end
  end
end
