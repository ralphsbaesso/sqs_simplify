# frozen_string_literal: true

module SqsSimplify
  class Message
    attr_accessor :body, :delay_seconds, :queue_url, :group_id

    def initialize(body:, queue_url:, delay_seconds: 0, group_id: nil)
      self.body = body
      self.delay_seconds = delay_seconds
      self.queue_url = queue_url
      self.group_id = group_id
    end

    def to_send
      hash = {
        queue_url: queue_url,
        message_body: body,
        delay_seconds: delay_seconds
      }
      hash[:message_group_id] = group_id.to_s if group_id
      hash
    end
  end
end
