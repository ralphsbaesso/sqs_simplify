# frozen_string_literal: true

RSpec.describe SqsSimplify::Message do
  describe '#to_send' do
    it 'includes message_group_id when group_id present' do
      message = described_class.new(queue_url: 'http://amazon.com', body: 'body', group_id: 'group-1')
      expect(message.to_send).to include(message_group_id: 'group-1')
    end

    it 'omits message_group_id when absent' do
      message = described_class.new(queue_url: 'http://amazon.com', body: 'body')
      expect(message.to_send).to_not have_key(:message_group_id)
    end
  end
end
