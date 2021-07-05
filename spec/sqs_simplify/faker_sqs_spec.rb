# frozen_string_literal: true

RSpec.describe SqsSimplify::FakerClient do
  before do
    SqsSimplify.settings.faker = true
    SchedulerExample.instance_variable_set(:@client, nil)
    ConsumerExample.instance_variable_set(:@client, nil)
  end

  after do
    SqsSimplify.settings.faker = false
    SchedulerExample.instance_variable_set(:@client, nil)
    ConsumerExample.instance_variable_set(:@client, nil)
  end

  context 'send e receive message' do
    it 'send one message' do
      message = { id: 1, text: 'text test' }
      response = SchedulerExample.send_message(message: message)
      expect(response).not_to be_nil

      expect(SqsSimplify::FakerClient.pool.count).to eq(1)
      expect(SchedulerExample.count_messages).to eq(1)

      messages = ConsumerExample.send :fetch_messages
      expect(messages.count).to eq(1)

      ConsumerExample.send :delete_sqs_message, messages.first
      expect(SchedulerExample.count_messages).to eq(0)
    end

    it 'send multiples messages' do
      15.times do |index|
        message = { id: index, text: 'text' }
        SchedulerExample.send_message(message: message)
      end

      expect(SchedulerExample.count_messages).to eq(15)

      messages = ConsumerExample.send :fetch_messages, 9
      messages.each do |message|
        ConsumerExample.send :delete_sqs_message, message
      end

      expect(SchedulerExample.count_messages).to eq(6)

      messages = ConsumerExample.send :fetch_messages, 4
      messages.each do |message|
        ConsumerExample.send :delete_sqs_message, message
      end

      expect(SchedulerExample.count_messages).to eq(2)
      expect(SqsSimplify::FakerClient.pool.count).to eq(2)
    end
  end
end
